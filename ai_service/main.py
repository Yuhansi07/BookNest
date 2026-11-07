import os
import re
from collections import Counter
from datetime import date, datetime, time, timezone
from pathlib import Path
from typing import Optional

import numpy as np
import psycopg2
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from psycopg2.extras import RealDictCursor
from pydantic import BaseModel
from sklearn.ensemble import IsolationForest
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LinearRegression
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.preprocessing import StandardScaler

BASE_DIR = Path(__file__).resolve().parent
ENV_FILE = BASE_DIR / '.env'
load_dotenv(dotenv_path=ENV_FILE, override=True)

app = FastAPI(
    title='Library AI/ML Service',
    version='2.1.0',
    description='Recommendations, smart search, member risk, demand forecasting, anomaly detection and a grounded library AI assistant.',
)


def get_connection():
    database_url = os.getenv('DATABASE_URL')
    if database_url:
        return psycopg2.connect(database_url, cursor_factory=RealDictCursor)

    password = os.getenv('DB_PASSWORD')
    if not password:
        raise RuntimeError(f'DB_PASSWORD is missing. Check {ENV_FILE}')

    return psycopg2.connect(
        host=os.getenv('DB_HOST', 'localhost'),
        port=int(os.getenv('DB_PORT', '5432')),
        dbname=os.getenv('DB_NAME', 'library_db'),
        user=os.getenv('DB_USER', 'postgres'),
        password=password,
        cursor_factory=RealDictCursor,
    )


def fetch_all(query, params=None):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(query, params or ())
            return cur.fetchall()
    finally:
        conn.close()


def fetch_one(query, params=None):
    rows = fetch_all(query, params)
    return rows[0] if rows else None


def book_text(book):
    parts = [
        book.get('title') or '',
        book.get('author') or '',
        book.get('category') or '',
        book.get('publisher') or '',
        book.get('description') or '',
    ]
    return ' '.join(str(v).strip() for v in parts if str(v).strip())


def get_books():
    return fetch_all(
        '''
        SELECT id, isbn, title, author,
               COALESCE(category,'') AS category,
               COALESCE(publisher,'') AS publisher,
               COALESCE(description,'') AS description,
               COALESCE(cover_url,'') AS cover_url,
               COALESCE(total_copies,0) AS total_copies,
               COALESCE(available_copies,0) AS available_copies
        FROM books
        ORDER BY id
        '''
    )


def serialize_book(book, score: Optional[float] = None, reason: Optional[str] = None):
    data = {
        'id': int(book['id']),
        'isbn': book.get('isbn'),
        'title': book.get('title'),
        'author': book.get('author'),
        'category': book.get('category'),
        'publisher': book.get('publisher'),
        'description': book.get('description'),
        'cover_url': book.get('cover_url'),
        'total_copies': int(book.get('total_copies') or 0),
        'available_copies': int(book.get('available_copies') or 0),
    }
    if score is not None:
        data['score'] = round(float(score), 4)
    if reason:
        data['reason'] = reason
    return data


def get_popularity():
    rows = fetch_all(
        '''
        SELECT b.id, COUNT(l.id)::int AS borrow_count
        FROM books b
        LEFT JOIN loans l ON l.book_id=b.id
        GROUP BY b.id
        '''
    )
    return {int(row['id']): int(row['borrow_count']) for row in rows}


def get_member_history(member_id: int):
    return fetch_all(
        '''
        SELECT DISTINCT b.id, b.isbn, b.title, b.author,
               COALESCE(b.category,'') AS category,
               COALESCE(b.publisher,'') AS publisher,
               COALESCE(b.description,'') AS description,
               COALESCE(b.cover_url,'') AS cover_url,
               COALESCE(b.total_copies,0) AS total_copies,
               COALESCE(b.available_copies,0) AS available_copies
        FROM loans l
        JOIN books b ON b.id=l.book_id
        WHERE l.member_id=%s
        ORDER BY b.id
        ''',
        (member_id,),
    )


def to_utc_datetime(value):
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
    if isinstance(value, date):
        return datetime.combine(value, time.max, tzinfo=timezone.utc)
    return None


class SearchBody(BaseModel):
    query: str
    limit: int = 6


class ChatBody(BaseModel):
    message: str
    role: str = ''
    member_id: Optional[int] = None
    user_name: str = ''


@app.get('/health')
def health():
    try:
        row = fetch_one('SELECT current_database() AS db')
        return {
            'status': 'ok',
            'service': 'library-ai',
            'version': '2.1.0',
            'database': row['db'] if row else None,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post('/search')
def smart_search(body: SearchBody):
    query = body.query.strip()
    limit = max(1, min(body.limit, 20))
    if not query:
        raise HTTPException(status_code=400, detail='query is required')

    books = get_books()
    if not books:
        return {'query': query, 'method': 'tfidf_query_similarity', 'results': []}

    corpus = [book_text(book) for book in books]
    try:
        vectorizer = TfidfVectorizer(lowercase=True, ngram_range=(1, 2), stop_words='english')
        matrix = vectorizer.fit_transform(corpus + [query])
    except ValueError:
        return {'query': query, 'method': 'tfidf_query_similarity', 'results': []}

    query_vector = matrix[-1]
    scores = cosine_similarity(query_vector, matrix[:-1]).flatten()
    ranked = np.argsort(scores)[::-1]

    results = []
    for idx in ranked:
        score = float(scores[int(idx)])
        if score <= 0:
            continue
        results.append(
            serialize_book(
                books[int(idx)],
                score=score,
                reason=f'Matched to "{query}" using TF-IDF text similarity',
            )
        )
        if len(results) >= limit:
            break

    return {'query': query, 'method': 'tfidf_query_similarity', 'results': results}


@app.get('/similar-books/{book_id}')
def similar_books(book_id: int, limit: int = 5):
    limit = max(1, min(limit, 20))
    books = get_books()
    if not books:
        return {'book_id': book_id, 'method': 'tfidf_content_similarity', 'results': []}

    id_to_index = {int(book['id']): i for i, book in enumerate(books)}
    if book_id not in id_to_index:
        raise HTTPException(status_code=404, detail='Book not found')

    corpus = [book_text(book) for book in books]
    try:
        matrix = TfidfVectorizer(lowercase=True, ngram_range=(1, 2), stop_words='english').fit_transform(corpus)
    except ValueError:
        return {'book_id': book_id, 'method': 'tfidf_content_similarity', 'results': []}

    source_index = id_to_index[book_id]
    scores = cosine_similarity(matrix[source_index], matrix).flatten()
    popularity = get_popularity()

    ranked = []
    for idx, score in enumerate(scores):
        if idx == source_index:
            continue
        book = books[idx]
        availability_bonus = 0.03 if int(book.get('available_copies') or 0) > 0 else 0.0
        popularity_bonus = min(popularity.get(int(book['id']), 0), 10) * 0.002
        ranked.append((float(score) + availability_bonus + popularity_bonus, book))

    ranked.sort(key=lambda item: item[0], reverse=True)
    return {
        'book_id': book_id,
        'method': 'tfidf_content_similarity',
        'results': [
            serialize_book(book, score=score, reason='Similar title, author, category or description')
            for score, book in ranked[:limit]
        ],
    }


@app.get('/recommendations/member/{member_id}')
def recommendations(member_id: int, limit: int = 6):
    limit = max(1, min(limit, 20))
    member = fetch_one('SELECT id, member_code, name FROM members WHERE id=%s', (member_id,))
    if not member:
        raise HTTPException(status_code=404, detail='Member not found')

    books = get_books()
    history = get_member_history(member_id)
    history_ids = {int(book['id']) for book in history}
    popularity = get_popularity()
    candidates = [book for book in books if int(book['id']) not in history_ids]

    if not candidates:
        return {'member': member, 'method': 'no_unseen_books', 'history_count': len(history), 'recommendations': []}

    if not history:
        ranked = sorted(
            candidates,
            key=lambda book: (
                int(book.get('available_copies') or 0) > 0,
                popularity.get(int(book['id']), 0),
                int(book.get('available_copies') or 0),
            ),
            reverse=True,
        )[:limit]
        return {
            'member': member,
            'method': 'popular_fallback',
            'history_count': 0,
            'recommendations': [
                serialize_book(
                    book,
                    score=float(popularity.get(int(book['id']), 0)),
                    reason='Popular choice while the member builds borrowing history',
                )
                for book in ranked
            ],
        }

    corpus = [book_text(book) for book in books]
    try:
        matrix = TfidfVectorizer(lowercase=True, ngram_range=(1, 2), stop_words='english').fit_transform(corpus)
    except ValueError:
        matrix = None

    if matrix is None:
        return {'member': member, 'method': 'empty_text', 'history_count': len(history), 'recommendations': []}

    id_to_index = {int(book['id']): i for i, book in enumerate(books)}
    history_indexes = [id_to_index[int(book['id'])] for book in history if int(book['id']) in id_to_index]
    profile_vector = np.asarray(matrix[history_indexes].mean(axis=0))

    scored = []
    for book in candidates:
        idx = id_to_index[int(book['id'])]
        similarity = float(cosine_similarity(profile_vector, matrix[idx])[0][0])
        availability_bonus = 0.03 if int(book.get('available_copies') or 0) > 0 else 0.0
        popularity_bonus = min(popularity.get(int(book['id']), 0), 10) * 0.002
        score = similarity + availability_bonus + popularity_bonus
        reason = "Similar to this member's borrowing interests"
        if book.get('category'):
            reason += f" • {book['category']}"
        scored.append((score, book, reason))

    scored.sort(key=lambda item: item[0], reverse=True)
    return {
        'member': member,
        'method': 'tfidf_content_based',
        'history_count': len(history),
        'recommendations': [serialize_book(book, score=score, reason=reason) for score, book, reason in scored[:limit]],
    }


@app.get('/member-risk/{member_id}')
def member_risk(member_id: int):
    member = fetch_one('SELECT id, member_code, name, status FROM members WHERE id=%s', (member_id,))
    if not member:
        raise HTTPException(status_code=404, detail='Member not found')

    loans = fetch_all(
        '''
        SELECT issue_date, due_date, return_date, status, COALESCE(fine,0) AS fine,
               COALESCE(fine_paid,false) AS fine_paid
        FROM loans WHERE member_id=%s ORDER BY issue_date
        ''',
        (member_id,),
    )

    if not loans:
        return {
            'member': member,
            'model': 'history_rules_fallback',
            'risk_score': 0.05,
            'risk_level': 'Low',
            'risk_reason': 'No negative borrowing history is available yet.',
            'features': {'total_loans': 0, 'late_loans': 0, 'late_ratio': 0.0, 'total_fines': 0.0, 'unpaid_fines': 0.0},
        }

    now = datetime.now(timezone.utc)
    late_loans = 0
    total_fines = 0.0
    unpaid_fines = 0.0

    for loan in loans:
        due = to_utc_datetime(loan.get('due_date'))
        returned = to_utc_datetime(loan.get('return_date'))
        compare_time = returned or now
        if due and compare_time > due:
            late_loans += 1
        fine = float(loan.get('fine') or 0)
        total_fines += fine
        if not loan.get('fine_paid'):
            unpaid_fines += fine

    total_loans = len(loans)
    late_ratio = late_loans / total_loans if total_loans else 0.0
    risk_score = min(0.95, 0.08 + late_ratio * 0.65 + min(unpaid_fines / 5000.0, 0.22))
    risk_level = 'High' if risk_score >= 0.65 else 'Medium' if risk_score >= 0.35 else 'Low'

    reasons = []
    if late_ratio >= 0.5:
        reasons.append('frequent late returns')
    elif late_loans > 0:
        reasons.append('some late returns')
    if unpaid_fines > 0:
        reasons.append('unpaid fines')
    if not reasons:
        reasons.append('good repayment and return behaviour')

    return {
        'member': member,
        'model': 'history_risk_scoring',
        'risk_score': round(risk_score, 4),
        'risk_level': risk_level,
        'risk_reason': ', '.join(reasons).capitalize(),
        'features': {
            'total_loans': total_loans,
            'late_loans': late_loans,
            'late_ratio': round(late_ratio, 4),
            'total_fines': round(total_fines, 2),
            'unpaid_fines': round(unpaid_fines, 2),
        },
    }


@app.get('/demand-forecast')
def demand_forecast(months: int = 6, limit: int = 8):
    months = max(3, min(months, 24))
    limit = max(1, min(limit, 30))

    rows = fetch_all(
        '''
        WITH months AS (
          SELECT generate_series(
            date_trunc('month', CURRENT_DATE) - make_interval(months => %s),
            date_trunc('month', CURRENT_DATE),
            interval '1 month'
          ) AS month
        ), book_months AS (
          SELECT b.id, b.title, b.author, b.category, m.month
          FROM books b CROSS JOIN months m
        )
        SELECT bm.id, bm.title, bm.author, bm.category,
               TO_CHAR(bm.month,'YYYY-MM') AS month,
               COUNT(l.id)::int AS borrow_count
        FROM book_months bm
        LEFT JOIN loans l ON l.book_id=bm.id
          AND date_trunc('month',l.issue_date)=bm.month
        GROUP BY bm.id,bm.title,bm.author,bm.category,bm.month
        ORDER BY bm.id,bm.month
        ''',
        (months,),
    )

    grouped = {}
    for row in rows:
        grouped.setdefault(int(row['id']), {'book': row, 'history': []})['history'].append(int(row['borrow_count']))

    forecasts = []
    for book_id, data in grouped.items():
        y = np.array(data['history'], dtype=float)
        x = np.arange(len(y), dtype=float).reshape(-1, 1)
        if len(y) >= 3:
            model = LinearRegression().fit(x, y)
            predicted = max(0.0, float(model.predict([[len(y)]])[0]))
            slope = float(model.coef_[0])
        else:
            predicted = float(np.mean(y)) if len(y) else 0.0
            slope = 0.0

        average = float(np.mean(y)) if len(y) else 0.0
        demand_score = predicted + max(0.0, slope) + average * 0.25
        level = 'High' if predicted >= 4 or demand_score >= 5 else 'Medium' if predicted >= 2 or demand_score >= 2 else 'Low'
        row = data['book']
        forecasts.append({
            'book_id': book_id,
            'title': row['title'],
            'author': row['author'],
            'category': row['category'],
            'history': data['history'],
            'predicted_next_month': round(predicted, 2),
            'trend_slope': round(slope, 3),
            'demand_level': level,
            'demand_score': round(demand_score, 3),
        })

    forecasts.sort(key=lambda item: item['demand_score'], reverse=True)
    return {
        'model': 'linear_regression_per_book_with_fallback',
        'history_months': months,
        'forecast': forecasts[:limit],
    }


@app.get('/anomalies')
def anomalies(limit: int = 8):
    limit = max(1, min(limit, 30))
    rows = fetch_all(
        '''
        SELECT m.id, m.member_code, m.name,
               COALESCE(ls.total_loans,0)::int AS total_loans,
               COALESCE(ls.late_loans,0)::int AS late_loans,
               COALESCE(ls.total_fines,0)::float AS total_fines,
               COALESCE(ls.unpaid_fines,0)::float AS unpaid_fines,
               COALESCE(rs.reservations,0)::int AS reservations
        FROM members m
        LEFT JOIN LATERAL (
          SELECT
            COUNT(*)::int AS total_loans,
            COUNT(*) FILTER (
              WHERE (l.return_date IS NOT NULL AND l.return_date::date > l.due_date::date)
                 OR (l.return_date IS NULL AND l.status='Issued' AND l.due_date::date < CURRENT_DATE)
            )::int AS late_loans,
            COALESCE(SUM(l.fine),0)::float AS total_fines,
            COALESCE(SUM(l.fine) FILTER (WHERE COALESCE(l.fine_paid,false)=false),0)::float AS unpaid_fines
          FROM loans l WHERE l.member_id=m.id
        ) ls ON TRUE
        LEFT JOIN LATERAL (
          SELECT COUNT(*)::int AS reservations
          FROM reservations r WHERE r.member_id=m.id
        ) rs ON TRUE
        ORDER BY m.id
        '''
    )

    if not rows:
        return {'model': 'none', 'anomalies': []}

    features = []
    for row in rows:
        total = int(row['total_loans'])
        late = int(row['late_loans'])
        features.append([
            total,
            late / total if total else 0.0,
            float(row['total_fines'] or 0),
            float(row['unpaid_fines'] or 0),
            int(row['reservations']),
        ])

    x = np.asarray(features, dtype=float)
    if len(rows) >= 8:
        x_scaled = StandardScaler().fit_transform(x)
        model = IsolationForest(contamination='auto', random_state=42)
        labels = model.fit_predict(x_scaled)
        scores = -model.decision_function(x_scaled)
        method = 'isolation_forest'
    else:
        # Useful fallback for tiny demo datasets.
        scores = x[:, 1] * 0.55 + np.minimum(x[:, 3] / 5000.0, 0.3) + np.minimum(x[:, 0] / 20.0, 0.15)
        labels = np.where(scores > 0.45, -1, 1)
        method = 'rule_score_fallback_small_dataset'

    items = []
    for i, row in enumerate(rows):
        total_loans = int(row['total_loans'])
        late_loans = int(row['late_loans'])
        late_ratio = late_loans / total_loans if total_loans else 0.0
        unpaid_fines = float(row['unpaid_fines'] or 0)
        total_fines = float(row['total_fines'] or 0)
        reservation_count = int(row['reservations'])
        is_anomaly = bool(labels[i] == -1)
        raw_score = float(scores[i])

        reasons = []
        if late_ratio >= 0.5 and total_loans >= 2:
            reasons.append('high late-return ratio')
        elif late_loans > 0:
            reasons.append('late-return history')
        if unpaid_fines >= 1000:
            reasons.append('high unpaid fines')
        elif unpaid_fines > 0:
            reasons.append('unpaid fines')
        if total_loans >= 12:
            reasons.append('unusually high borrowing volume')
        if reservation_count >= 8:
            reasons.append('unusually high reservation activity')
        if not reasons:
            reasons.append('multivariate activity differs from the normal member pattern' if is_anomaly else 'activity is within the expected range')

        if is_anomaly and (late_ratio >= 0.6 or unpaid_fines >= 1500):
            severity = 'High'
        elif is_anomaly:
            severity = 'Medium'
        elif late_loans > 0 or unpaid_fines > 0:
            severity = 'Watch'
        else:
            severity = 'Normal'

        items.append({
            'member_id': int(row['id']),
            'member_code': row['member_code'],
            'name': row['name'],
            'anomaly': is_anomaly,
            'severity': severity,
            'reason': ', '.join(reasons).capitalize(),
            'anomaly_score': round(raw_score, 4),
            'features': {
                'total_loans': total_loans,
                'late_loans': late_loans,
                'late_ratio': round(late_ratio, 4),
                'total_fines': round(total_fines, 2),
                'unpaid_fines': round(unpaid_fines, 2),
                'reservations': reservation_count,
            },
        })

    items.sort(key=lambda item: (item['anomaly'], item['anomaly_score']), reverse=True)
    visible = items[:limit]
    return {
        'model': method,
        'scanned_members': len(rows),
        'detected_count': sum(1 for item in items if item['anomaly']),
        'anomalies': visible,
    }


# ============================================================
# GROUNDED LIBRARY AI ASSISTANT
# ============================================================

CHAT_INTENT_EXAMPLES = {
    'overview': [
        'library overview', 'how many books and members are there', 'show dashboard totals',
        'what is happening in the library', 'give me a summary', 'library status'
    ],
    'book_search': [
        'find a book', 'search books', 'do we have database systems', 'book availability',
        'is this book available', 'find books about databases', 'search by author'
    ],
    'popular_books': [
        'most borrowed books', 'popular books', 'top books', 'which books are popular'
    ],
    'overdue': [
        'overdue books', 'late loans', 'who has overdue books', 'show overdue loans'
    ],
    'fines': [
        'unpaid fines', 'fine summary', 'who owes fines', 'my fines', 'fine payments'
    ],
    'reservations': [
        'reservation status', 'show reservations', 'pending reservations', 'my reservations'
    ],
    'member_lookup': [
        'member details', 'find member mem001', 'show member profile', 'member borrowing details'
    ],
    'my_loans': [
        'my loans', 'what books do i have', 'my borrowed books', 'when are my books due'
    ],
    'recommendations': [
        'recommend a book', 'book recommendations', 'what should i read', 'suggest books for me'
    ],
    'anomalies': [
        'anomaly detection', 'unusual borrowing', 'suspicious activity', 'high risk members',
        'show anomalies', 'which members look unusual'
    ],
    'forecast': [
        'demand forecast', 'what books will be popular next month', 'restock recommendations',
        'which books need restocking', 'future demand'
    ],
    'help': [
        'help', 'what can you do', 'commands', 'how can you help me'
    ],
}

_CHAT_PHRASES = []
_CHAT_LABELS = []
for _label, _examples in CHAT_INTENT_EXAMPLES.items():
    for _example in _examples:
        _CHAT_PHRASES.append(_example)
        _CHAT_LABELS.append(_label)

_CHAT_VECTORIZER = TfidfVectorizer(lowercase=True, ngram_range=(1, 2), stop_words='english')
_CHAT_MATRIX = _CHAT_VECTORIZER.fit_transform(_CHAT_PHRASES)


# Catalogue topic synonyms
TOPIC_ALIASES = {
    'travel': {
        'travel','travels','travelling','traveling',
        'tour','tours','tourism','trip','trips',
        'journey','journeys','holiday','vacation',
        'destination','explore','exploring',
        'sightseeing','backpacking'
    },
    'culture': {
        'culture','cultures','cultural',
        'tradition','traditions'
    },
    'technology': {
        'technology','computing','computer',
        'computers','tech'
    },
    'programming': {
        'programming','coding','software',
        'python','javascript'
    },
    'science': {'science','scientific','physics'},
    'history': {'history','historical'},
    'romance': {'romance','romantic','love'},
    'mystery': {'mystery','detective','crime','thriller'},
    'fantasy': {'fantasy','magic'},
    'business': {'business','management','entrepreneurship'},
    'health': {'health','wellness'}
}

TOPIC_NOISE = {
    'i','me','my','a','an','the','for','to',
    'of','about','like','with','please','want',
    'need','looking','find','show','give',
    'book','books','read','reading',
    'recommend','suggest','some','any',
    'good','best','can','you','have','do',
    'your','in','on','available'
}

def chat_terms(text, remove_noise=False):
    result = set()

    for word in re.findall(
        r'[a-z0-9]+',
        str(text).lower()
    ):
        if remove_noise and (
            word in TOPIC_NOISE or len(word) < 3
        ):
            continue

        normalized = next(
            (
                key
                for key, vals in TOPIC_ALIASES.items()
                if word in vals
            ),
            word
        )

        result.add(normalized)

    return result


_CHAT_ALIASES = {
    'travelling':'travel',
    'traveling':'travel',
    'travels':'travel',
    'tour':'travel',
    'tourism':'travel',
    'trip':'travel',
    'trips':'travel',
    'journey':'travel',
    'journeys':'travel',
    'holiday':'travel',
    'vacation':'travel',
    'backpacking':'travel',
    'destinations':'travel',
    'exploring':'travel',
    'explore':'travel',
    'cultures':'culture',
    'cultural':'culture',
    'computers':'computer',
    'computing':'computer',
    'novels':'novel',
    'romantic':'romance',
    'historical':'history',
    'programming':'program',
    'coding':'program',
    'thrillers':'thriller',
}

_CHAT_STOP = {
    'a','an','and','are','about','any',
    'book','books','by','can','could',
    'do','find','for','give','good',
    'have','i','in','is','like',
    'looking','me','my','need','novel',
    'of','on','please','read','reading',
    'recommend','search','show','some',
    'suggest','the','title','to','want',
    'with','would','you','available',
    'best','get','related',
}

def _chat_topic_terms(text, strip_common=False):
    terms = set()

    for word in re.findall(
        r'[a-z0-9]+',
        str(text).lower()
    ):
        if strip_common and (
            word in _CHAT_STOP or len(word) < 3
        ):
            continue

        terms.add(
            _CHAT_ALIASES.get(word, word)
        )

    return terms


# LIBRARY_AI_TOPIC_RELEVANCE_V2

_BOOK_ALIASES = {
    'travelling': 'travel',
    'traveling': 'travel',
    'travels': 'travel',
    'journey': 'travel',
    'journeys': 'travel',
    'trip': 'travel',
    'trips': 'travel',
    'tour': 'travel',
    'tourism': 'travel',
    'holiday': 'travel',
    'vacation': 'travel',
    'backpacking': 'travel',
    'destination': 'travel',
    'destinations': 'travel',
    'explore': 'travel',
    'exploring': 'travel',
    'healthy': 'health',
    'wellness': 'health',
    'cultures': 'culture',
    'cultural': 'culture',
    'computing': 'computer',
    'computers': 'computer',
    'databases': 'database',
    'romantic': 'romance',
    'historical': 'history',
    'coding': 'programming',
}

_BOOK_STOP = {
    'i', 'me', 'my', 'a', 'an', 'the',
    'and', 'or', 'is', 'are', 'for',
    'to', 'of', 'on', 'in', 'about',
    'like', 'with', 'please', 'want',
    'need', 'looking', 'find', 'show',
    'give', 'book', 'books', 'read',
    'reading', 'novel', 'recommend',
    'recommendation', 'recommendations',
    'suggest', 'some', 'any', 'good',
    'best', 'can', 'you', 'do',
    'have', 'your', 'available',
    'availability', 'tell', 'what',
    'which', 'new', 'something',
    'related', 'topic', 'popular',
    'most', 'top', 'help', 'pick',
    'choice', 'get', 'there', 'that',
    'this', 'one', 'library',
}

def _book_terms(value, skip_stop=False):
    words = re.findall(
        r'[a-z0-9]+',
        str(value or '').lower()
    )

    return {
        _BOOK_ALIASES.get(w, w)
        for w in words
        if not (
            skip_stop and (
                w in _BOOK_STOP or len(w) < 3
            )
        )
    }

def _topic_request(message):
    lower = message.lower()

    if not re.search(
        r'\b(books?|reading|read|novels?|recommend|suggest|find)\b',
        lower
    ):
        return False

    if any(w in lower for w in (
        'my loan', 'my borrowed',
        'due date', 'my fine',
        'my reservation', 'overdue',
        'borrowed books',
    )):
        return False

    return bool(
        _book_terms(message, skip_stop=True)
    )

def classify_chat_intent(message: str):
    text = message.lower().strip()

    if (
        re.search(
            r'\b(book|books|read|reading|recommend|suggest|novel|title)\b',
            text
        )
        and _chat_topic_terms(
            message,
            strip_common=True
        )
        and not re.search(
            r'\b(my loans?|my fines?|my reservations?|overdue)\b',
            text
        )
    ):
        return 'book_search', 0.99  # topic evidence

    if (
        re.search(
            r'\b(book|books|read|reading|novel|title|recommend)\b',
            text
        )
        and chat_terms(message, remove_noise=True)
        and not any(
            k in text
            for k in [
                'my loan',
                'my fine',
                'my reservation',
                'overdue'
            ]
        )
    ):
        return 'book_search', 0.98
    if any(k in text for k in ['anomaly', 'unusual', 'suspicious', 'high risk', 'high-risk']):
        return 'anomalies', 1.0
    if any(k in text for k in ['forecast', 'future demand', 'restock', 'next month demand']):
        return 'forecast', 1.0
    if 'overdue' in text or 'late loan' in text or 'late book' in text:
        return 'overdue', 1.0
    if 'fine' in text:
        return 'fines', 1.0
    if 'reservation' in text or 'reserved' in text:
        return 'reservations', 1.0
    if 'my loan' in text or 'my borrowed' in text or 'books do i have' in text:
        return 'my_loans', 1.0
    if _topic_request(message):
        return 'book_search', 0.99
    if 'recommend' in text or 'suggest' in text or 'what should i read' in text:
        return 'recommendations', 1.0
    if 'popular' in text or 'most borrowed' in text or 'top book' in text:
        return 'popular_books', 1.0
    if re.search(r'\bmem\s*[-_]?\s*\d+\b', text, flags=re.I):
        return 'member_lookup', 0.98
    if any(k in text for k in ['available', 'availability', 'find book', 'search book', 'do we have', 'isbn']):
        return 'book_search', 0.94

    vector = _CHAT_VECTORIZER.transform([message])
    similarities = cosine_similarity(vector, _CHAT_MATRIX).flatten()
    idx = int(np.argmax(similarities))
    score = float(similarities[idx])
    label = _CHAT_LABELS[idx]
    if score < 0.11:
        return 'book_search', score
    return label, score


def chat_card(title, subtitle='', meta='', kind='info'):
    return {
        'type': kind,
        'title': str(title or ''),
        'subtitle': str(subtitle or ''),
        'meta': str(meta or ''),
    }


def chat_response(answer, intent, confidence=1.0, cards=None, suggestions=None):
    return {
        'answer': answer,
        'intent': intent,
        'confidence': round(float(confidence), 4),
        'cards': cards or [],
        'suggestions': suggestions or [],
    }


def member_code_from_message(message: str):
    match = re.search(r'\bMEM\s*[-_]?\s*(\d+)\b', message, flags=re.I)
    if not match:
        return None
    return f"MEM{match.group(1)}"


def get_member_by_message(message: str):
    code = member_code_from_message(message)
    if code:
        member = fetch_one(
            "SELECT id, member_code, name, email, phone, status FROM members WHERE UPPER(REPLACE(member_code,'-',''))=%s LIMIT 1",
            (code.upper().replace('-', ''),),
        )
        if member:
            return member

    members = fetch_all('SELECT id, member_code, name, email, phone, status FROM members ORDER BY id')
    if not members:
        return None

    message_words = {
        w for w in re.findall(r'[a-zA-Z]{3,}', message.lower())
        if w not in {
            'show', 'find', 'member', 'details', 'profile', 'about', 'please', 'give', 'information',
            'borrowing', 'history', 'current', 'loan', 'loans', 'the', 'for', 'with'
        }
    }
    best = None
    best_score = 0
    for member in members:
        name_words = set(re.findall(r'[a-zA-Z]{3,}', str(member.get('name') or '').lower()))
        score = len(message_words & name_words)
        if score > best_score:
            best = member
            best_score = score
    return best if best_score > 0 else None




def search_books_for_chat(
    message: str,
    limit: int = 5
):
    books = get_books()

    if not books:
        return []

    words = _book_terms(
        message,
        skip_stop=True
    )

    want_available = 'available' in message.lower()

    if not words:
        if want_available:
            return sorted(
                (
                    b for b in books
                    if int(
                        b.get('available_copies') or 0
                    ) > 0
                ),
                key=lambda b: str(
                    b.get('title') or ''
                ).lower(),
            )[:limit]

        return []

    ranked = []

    for book in books:
        if want_available and int(
            book.get('available_copies') or 0
        ) <= 0:
            continue

        title = _book_terms(
            book.get('title')
        )

        category = _book_terms(
            book.get('category')
        )

        author = _book_terms(
            book.get('author')
        )

        description = _book_terms(
            book.get('description')
        )

        isbn = str(
            book.get('isbn') or ''
        ).lower()

        score = sum(
            8 * (term in title)
            + 10 * (term in category)
            + 4 * (term in author)
            + 2 * (term in description)
            + 12 * (
                term in isbn if isbn else False
            )
            for term in words
        )

        if score > 0:
            ranked.append((
                score,
                int(
                    book.get('available_copies') or 0
                ),
                book
            ))

    ranked.sort(
        key=lambda item: (
            item[0],
            item[1]
        ),
        reverse=True
    )

    return [
        book
        for _, _, book in ranked[:limit]
    ]

def staff_only(role: str):
    return role.lower() in {'admin', 'librarian'}


@app.post('/chat')
def library_chat(body: ChatBody):
    message = body.message.strip()
    if not message:
        raise HTTPException(status_code=400, detail='message is required')

    role = (body.role or '').strip().lower()
    member_id = body.member_id
    intent, confidence = classify_chat_intent(message)

    general_suggestions = [
        'Show library overview',
        'Which books are popular?',
        'Find available database books',
    ]
    if staff_only(role):
        general_suggestions += ['Show anomaly alerts', 'Forecast next month demand']
    else:
        general_suggestions += ['Show my loans', 'Recommend a book for me']

    if intent == 'help':
        if staff_only(role):
            answer = (
                'I can search the catalogue, check availability, summarize overdue loans and fines, '
                'find members, show popular books, run anomaly detection, and explain demand forecasts. '
                'I only perform read-only assistant actions.'
            )
        else:
            answer = (
                'I can search books, check availability, show your loans/reservations/fines and recommend books '
                'using your borrowing history.'
            )
        return chat_response(answer, intent, confidence, suggestions=general_suggestions)

    if intent == 'overview':
        book_stats = fetch_one(
            '''SELECT COUNT(*)::int AS titles,
                      COALESCE(SUM(total_copies),0)::int AS copies,
                      COALESCE(SUM(available_copies),0)::int AS available
               FROM books'''
        ) or {}
        member_stats = fetch_one('SELECT COUNT(*)::int AS members FROM members') or {}
        loan_stats = fetch_one(
            '''SELECT COUNT(*) FILTER (WHERE status='Issued')::int AS active,
                      COUNT(*) FILTER (WHERE status='Issued' AND due_date::date < CURRENT_DATE)::int AS overdue
               FROM loans'''
        ) or {}
        answer = (
            f"The library has {book_stats.get('titles', 0)} titles and {book_stats.get('copies', 0)} total copies. "
            f"{book_stats.get('available', 0)} copies are available, there are {member_stats.get('members', 0)} members, "
            f"{loan_stats.get('active', 0)} active loans and {loan_stats.get('overdue', 0)} overdue loans."
        )
        cards = [
            chat_card('Book titles', book_stats.get('titles', 0), f"{book_stats.get('available', 0)} copies available", 'metric'),
            chat_card('Members', member_stats.get('members', 0), 'registered', 'metric'),
            chat_card('Active loans', loan_stats.get('active', 0), f"{loan_stats.get('overdue', 0)} overdue", 'metric'),
        ]
        return chat_response(answer, intent, confidence, cards, general_suggestions)

    if intent == 'book_search':
        books = search_books_for_chat(message, limit=5)
        if not books:
            return chat_response(
                'I searched the catalogue but found no relevant title for that topic.',
                intent,
                confidence,
                suggestions=['Find available books', 'Recommend a book for me'],
            )
        cards = []
        for book in books:
            available = int(book.get('available_copies') or 0)
            total = int(book.get('total_copies') or 0)
            cards.append(chat_card(
                book.get('title'),
                f"{book.get('author') or 'Unknown author'} • {book.get('category') or 'Uncategorised'}",
                f"{available}/{total} available • ISBN {book.get('isbn') or '-'}",
                'book',
            ))
        top = books[0]
        answer = (
            f"Best match: {top.get('title')} by {top.get('author')}. "
            f"{int(top.get('available_copies') or 0)} of {int(top.get('total_copies') or 0)} copies are available."
        )
        return chat_response(answer, intent, confidence, cards, ['Show popular books', 'Recommend a book', 'Library overview'])

    if intent == 'popular_books':
        rows = fetch_all(
            '''SELECT b.id, b.title, b.author, COUNT(l.id)::int AS borrows,
                      COALESCE(b.available_copies,0)::int AS available_copies
               FROM books b LEFT JOIN loans l ON l.book_id=b.id
               GROUP BY b.id,b.title,b.author,b.available_copies
               ORDER BY borrows DESC,b.title LIMIT 5'''
        )
        if not rows:
            return chat_response('There are no books in the catalogue yet.', intent, confidence, suggestions=general_suggestions)
        cards = [chat_card(r['title'], r['author'], f"{r['borrows']} borrows • {r['available_copies']} available", 'book') for r in rows]
        answer = f"The most borrowed title is {rows[0]['title']} with {rows[0]['borrows']} recorded borrow(s)."
        return chat_response(answer, intent, confidence, cards, ['Show library overview', 'Forecast next month demand'])

    if intent == 'overdue':
        if role == 'member':
            if not member_id:
                return chat_response('Your account is not linked to a member record.', intent, confidence)
            rows = fetch_all(
                '''SELECT l.id,b.title,l.due_date,COALESCE(l.fine,0) AS fine
                   FROM loans l JOIN books b ON b.id=l.book_id
                   WHERE l.member_id=%s AND l.status='Issued' AND l.due_date::date<CURRENT_DATE
                   ORDER BY l.due_date LIMIT 8''',
                (member_id,),
            )
        else:
            rows = fetch_all(
                '''SELECT l.id,b.title,m.member_code,m.name,l.due_date,COALESCE(l.fine,0) AS fine
                   FROM loans l JOIN books b ON b.id=l.book_id JOIN members m ON m.id=l.member_id
                   WHERE l.status='Issued' AND l.due_date::date<CURRENT_DATE
                   ORDER BY l.due_date LIMIT 8'''
            )
        if not rows:
            return chat_response('There are no overdue loans right now.', intent, confidence, suggestions=general_suggestions)
        cards = []
        for r in rows:
            who = '' if role == 'member' else f"{r['member_code']} • {r['name']} • "
            cards.append(chat_card(r['title'], f"{who}due {r['due_date']}", f"Fine LKR {float(r['fine'] or 0):.2f}", 'warning'))
        answer = f"I found {len(rows)} overdue loan(s) in this view."
        return chat_response(answer, intent, confidence, cards, ['Show unpaid fines', 'Show anomaly alerts'] if staff_only(role) else ['Show my loans'])

    if intent == 'fines':
        if role == 'member':
            if not member_id:
                return chat_response('Your account is not linked to a member record.', intent, confidence)
            row = fetch_one(
                '''SELECT COALESCE(SUM(fine),0)::float AS unpaid,
                          COUNT(*) FILTER (WHERE COALESCE(fine,0)>0 AND COALESCE(fine_paid,false)=false)::int AS count
                   FROM loans WHERE member_id=%s AND COALESCE(fine_paid,false)=false''',
                (member_id,),
            ) or {'unpaid': 0, 'count': 0}
            return chat_response(
                f"You have {row['count']} unpaid fine record(s), totalling LKR {float(row['unpaid'] or 0):.2f}.",
                intent,
                confidence,
                suggestions=['Show my loans', 'Show my reservations'],
            )
        rows = fetch_all(
            '''SELECT m.member_code,m.name,COALESCE(SUM(l.fine),0)::float AS unpaid
               FROM loans l JOIN members m ON m.id=l.member_id
               WHERE COALESCE(l.fine,0)>0 AND COALESCE(l.fine_paid,false)=false
               GROUP BY m.id,m.member_code,m.name ORDER BY unpaid DESC LIMIT 8'''
        )
        total = sum(float(r['unpaid'] or 0) for r in rows)
        cards = [chat_card(f"{r['member_code']} • {r['name']}", 'Unpaid fine', f"LKR {float(r['unpaid'] or 0):.2f}", 'warning') for r in rows]
        answer = f"The top unpaid-fine records in this view total LKR {total:.2f}." if rows else 'There are no unpaid fines right now.'
        return chat_response(answer, intent, confidence, cards, ['Show overdue loans', 'Show anomaly alerts'])

    if intent == 'reservations':
        if role == 'member':
            if not member_id:
                return chat_response('Your account is not linked to a member record.', intent, confidence)
            rows = fetch_all(
                '''SELECT r.id,b.title,r.status,r.reservation_date,r.expiry_date
                   FROM reservations r JOIN books b ON b.id=r.book_id
                   WHERE r.member_id=%s ORDER BY r.id DESC LIMIT 8''',
                (member_id,),
            )
            cards = [chat_card(r['title'], r['status'], f"Reserved {r['reservation_date']} • expires {r['expiry_date'] or '-'}", 'reservation') for r in rows]
            answer = f"You have {len(rows)} recent reservation record(s)." if rows else 'You do not have any reservation records yet.'
            return chat_response(answer, intent, confidence, cards, ['Show my loans', 'Recommend a book'])
        counts = fetch_all("SELECT status,COUNT(*)::int AS count FROM reservations GROUP BY status ORDER BY status")
        if not counts:
            return chat_response('There are no reservations yet.', intent, confidence, suggestions=general_suggestions)
        text = ', '.join(f"{r['count']} {str(r['status']).lower()}" for r in counts)
        cards = [chat_card(r['status'], r['count'], 'reservation records', 'metric') for r in counts]
        return chat_response(f"Reservation summary: {text}.", intent, confidence, cards, ['Show library overview'])

    if intent == 'member_lookup':
        if not staff_only(role):
            return chat_response('For privacy, member accounts can only access their own borrowing information.', intent, confidence, suggestions=['Show my loans', 'Recommend a book'])
        member = get_member_by_message(message)
        if not member:
            return chat_response('I could not identify the member. Try a member code such as MEM001 or include the member name.', intent, confidence)
        summary = fetch_one(
            '''SELECT COUNT(*)::int AS total_loans,
                      COUNT(*) FILTER (WHERE status='Issued')::int AS active_loans,
                      COALESCE(SUM(fine) FILTER (WHERE COALESCE(fine_paid,false)=false),0)::float AS unpaid
               FROM loans WHERE member_id=%s''',
            (member['id'],),
        ) or {}
        cards = [chat_card(
            f"{member['member_code']} • {member['name']}",
            f"{member.get('email') or '-'} • {member.get('status') or '-'}",
            f"{summary.get('active_loans',0)} active / {summary.get('total_loans',0)} total loans • LKR {float(summary.get('unpaid') or 0):.2f} unpaid",
            'member',
        )]
        return chat_response(
            f"{member['name']} is {member.get('status')}. I found {summary.get('total_loans',0)} total loan record(s).",
            intent,
            confidence,
            cards,
            [f"Show anomaly alerts", 'Show overdue loans'],
        )

    if intent == 'my_loans':
        if role != 'member':
            return chat_response('For staff, ask me about overdue loans or a member code such as MEM001.', intent, confidence, suggestions=['Show overdue loans', 'Find member MEM001'])
        if not member_id:
            return chat_response('Your login is not linked to a member record.', intent, confidence)
        rows = fetch_all(
            '''SELECT b.title,l.status,l.issue_date,l.due_date,l.return_date,COALESCE(l.fine,0) AS fine
               FROM loans l JOIN books b ON b.id=l.book_id
               WHERE l.member_id=%s ORDER BY l.id DESC LIMIT 10''',
            (member_id,),
        )
        cards = [chat_card(r['title'], f"{r['status']} • due {r['due_date']}", f"Fine LKR {float(r['fine'] or 0):.2f}", 'loan') for r in rows]
        answer = f"You have {len(rows)} recent loan record(s)." if rows else 'You do not have any loan records yet.'
        return chat_response(answer, intent, confidence, cards, ['Recommend a book for me', 'Show my fines'])

    if intent == 'recommendations':
        target_member_id = member_id if role == 'member' else None
        if staff_only(role):
            member = get_member_by_message(message)
            if member:
                target_member_id = int(member['id'])
            elif member_id:
                target_member_id = member_id
        if not target_member_id:
            rows = fetch_all(
                '''SELECT b.id,b.title,b.author,b.category,b.available_copies,COUNT(l.id)::int AS borrows
                   FROM books b LEFT JOIN loans l ON l.book_id=b.id
                   WHERE b.available_copies>0
                   GROUP BY b.id,b.title,b.author,b.category,b.available_copies
                   ORDER BY borrows DESC,b.available_copies DESC LIMIT 5'''
            )
            cards = [chat_card(r['title'], f"{r['author']} • {r['category'] or 'Uncategorised'}", f"{r['available_copies']} available • {r['borrows']} borrows", 'book') for r in rows]
            return chat_response('Here are popular available books. For personalised recommendations, use a member-linked login or include a member code.', intent, confidence, cards, general_suggestions)
        result = recommendations(int(target_member_id), limit=5)
        recs = result.get('recommendations', [])
        cards = [chat_card(r['title'], f"{r.get('author') or ''} • {r.get('category') or ''}", r.get('reason') or '', 'book') for r in recs]
        answer = f"I found {len(recs)} personalised recommendation(s) based on borrowing history." if recs else 'I do not have enough unseen catalogue items to recommend right now.'
        return chat_response(answer, intent, confidence, cards, ['Find available books', 'Show my loans'] if role == 'member' else ['Show popular books'])

    if intent == 'anomalies':
        if not staff_only(role):
            return chat_response('Anomaly detection is restricted to library staff because it compares member activity across the library.', intent, confidence, suggestions=['Show my loans', 'Recommend a book'])
        result = anomalies(limit=8)
        detected = [x for x in result.get('anomalies', []) if x.get('anomaly')]
        cards = [
            chat_card(
                f"{x.get('member_code')} • {x.get('name')}",
                f"{x.get('severity','Watch')} signal • score {float(x.get('anomaly_score') or 0):.3f}",
                x.get('reason') or 'Unusual multivariate borrowing pattern',
                'anomaly',
            )
            for x in detected[:6]
        ]
        if detected:
            answer = f"The {result.get('model')} scan flagged {result.get('detected_count', len(detected))} member pattern(s) across {result.get('scanned_members', 0)} scanned members."
        else:
            answer = f"The {result.get('model')} scan did not detect a strong anomaly in the current member data."
        return chat_response(answer, intent, confidence, cards, ['Forecast next month demand', 'Show overdue loans', 'Show unpaid fines'])

    if intent == 'forecast':
        if not staff_only(role):
            return chat_response('Demand forecasting is available to library staff.', intent, confidence, suggestions=['Recommend a book for me', 'Find available books'])
        result = demand_forecast(months=6, limit=6)
        rows = result.get('forecast', [])
        cards = [chat_card(r['title'], f"{r['demand_level']} predicted demand", f"Next month ≈ {r['predicted_next_month']} borrows • trend {r['trend_slope']}", 'forecast') for r in rows]
        high = [r for r in rows if r.get('demand_level') == 'High']
        answer = f"I forecast {len(high)} high-demand title(s) among the top {len(rows)} results." if rows else 'There is not enough borrowing history for a useful forecast yet.'
        return chat_response(answer, intent, confidence, cards, ['Show anomaly alerts', 'Show popular books'])

    return chat_response(
        'I can help with catalogue search, loans, fines, reservations, recommendations and library AI insights. Try one of the suggestions below.',
        intent,
        confidence,
        suggestions=general_suggestions,
    )


# ============================================================
# EXPANDED MEMBER RECOMMENDATION EXPERIENCE
# ============================================================

@app.get('/recommendations/member/{member_id}/expanded')
def expanded_member_recommendations(member_id: int, limit: int = 6):
    limit = max(1, min(limit, 12))

    member = fetch_one(
        'SELECT id, member_code, name FROM members WHERE id=%s',
        (member_id,),
    )
    if not member:
        raise HTTPException(status_code=404, detail='Member not found')

    history = get_member_history(member_id)
    history_ids = {int(book['id']) for book in history}

    base = recommendations(member_id, limit=limit)
    personalised = list(base.get('recommendations') or [])

    metrics = fetch_all(
        '''
        SELECT
            b.id,
            b.isbn,
            b.title,
            b.author,
            COALESCE(b.category,'') AS category,
            COALESCE(b.publisher,'') AS publisher,
            COALESCE(b.description,'') AS description,
            COALESCE(b.cover_url,'') AS cover_url,
            COALESCE(b.total_copies,0) AS total_copies,
            COALESCE(b.available_copies,0) AS available_copies,
            COUNT(DISTINCT l.id)::int AS borrow_count,
            COUNT(DISTINCT r.id) FILTER (
                WHERE r.status IN ('Pending','Ready')
            )::int AS reservation_count
        FROM books b
        LEFT JOIN loans l ON l.book_id=b.id
        LEFT JOIN reservations r ON r.book_id=b.id
        GROUP BY b.id
        ''',
    )

    def metric_item(book, score, reason):
        item = serialize_book(book, score=score, reason=reason)
        item['borrow_count'] = int(book.get('borrow_count') or 0)
        item['reservation_count'] = int(book.get('reservation_count') or 0)
        return item

    popular_ranked = sorted(
        metrics,
        key=lambda book: (
            int(book.get('borrow_count') or 0),
            int(book.get('reservation_count') or 0),
            int(book.get('available_copies') or 0),
        ),
        reverse=True,
    )
    popular_now = [
        metric_item(
            book,
            score=(int(book.get('borrow_count') or 0) * 2)
            + (int(book.get('reservation_count') or 0) * 3),
            reason=(
                f"Popular now: {int(book.get('borrow_count') or 0)} borrows and "
                f"{int(book.get('reservation_count') or 0)} active reservations"
            ),
        )
        for book in popular_ranked[:limit]
    ]

    highly_ranked = sorted(
        metrics,
        key=lambda book: (
            int(book.get('borrow_count') or 0) * 2
            + int(book.get('reservation_count') or 0) * 3
            + (1.0 if int(book.get('available_copies') or 0) > 0 else 0.0),
            int(book.get('available_copies') or 0),
        ),
        reverse=True,
    )
    highly_recommended = [
        metric_item(
            book,
            score=(int(book.get('borrow_count') or 0) * 2)
            + (int(book.get('reservation_count') or 0) * 3)
            + (1.0 if int(book.get('available_copies') or 0) > 0 else 0.0),
            reason='Highly recommended from circulation demand, reservations and current availability',
        )
        for book in highly_ranked[:limit]
    ]

    # "Because you borrowed..." uses real content similarity against the
    # member's most recently borrowed books.
    recent_history = fetch_all(
        '''
        SELECT
            b.id,
            b.isbn,
            b.title,
            b.author,
            COALESCE(b.category,'') AS category,
            COALESCE(b.publisher,'') AS publisher,
            COALESCE(b.description,'') AS description,
            COALESCE(b.cover_url,'') AS cover_url,
            COALESCE(b.total_copies,0) AS total_copies,
            COALESCE(b.available_copies,0) AS available_copies,
            MAX(l.issue_date) AS last_borrowed
        FROM loans l
        JOIN books b ON b.id=l.book_id
        WHERE l.member_id=%s
        GROUP BY b.id
        ORDER BY MAX(l.issue_date) DESC
        LIMIT 3
        ''',
        (member_id,),
    )

    because_you_borrowed = []
    books = get_books()
    if recent_history and books:
        id_to_index = {int(book['id']): index for index, book in enumerate(books)}
        corpus = [book_text(book) for book in books]
        try:
            matrix = TfidfVectorizer(
                lowercase=True,
                ngram_range=(1, 2),
                stop_words='english',
            ).fit_transform(corpus)
        except ValueError:
            matrix = None

        if matrix is not None:
            seen_candidates = set()
            candidates = [book for book in books if int(book['id']) not in history_ids]
            for source in recent_history:
                source_id = int(source['id'])
                if source_id not in id_to_index:
                    continue
                source_idx = id_to_index[source_id]
                scores = cosine_similarity(matrix[source_idx], matrix).flatten()
                ranked = sorted(
                    candidates,
                    key=lambda book: float(scores[id_to_index[int(book['id'])]])
                    + (0.03 if int(book.get('available_copies') or 0) > 0 else 0.0),
                    reverse=True,
                )
                for book in ranked:
                    book_id = int(book['id'])
                    similarity = float(scores[id_to_index[book_id]])
                    if book_id in seen_candidates or similarity <= 0:
                        continue
                    item = serialize_book(
                        book,
                        score=similarity,
                        reason=f"Because you borrowed {source['title']}",
                    )
                    item['source_title'] = source['title']
                    because_you_borrowed.append(item)
                    seen_candidates.add(book_id)
                    break
                if len(because_you_borrowed) >= limit:
                    break

    # Collaborative filtering: books borrowed by other members who share at
    # least one title with this member, excluding books already read by them.
    similar_rows = fetch_all(
        '''
        WITH mine AS (
            SELECT DISTINCT book_id
            FROM loans
            WHERE member_id=%s
        ),
        similar_members AS (
            SELECT DISTINCT l.member_id
            FROM loans l
            WHERE l.member_id<>%s
              AND l.book_id IN (SELECT book_id FROM mine)
        )
        SELECT
            b.id,
            b.isbn,
            b.title,
            b.author,
            COALESCE(b.category,'') AS category,
            COALESCE(b.publisher,'') AS publisher,
            COALESCE(b.description,'') AS description,
            COALESCE(b.cover_url,'') AS cover_url,
            COALESCE(b.total_copies,0) AS total_copies,
            COALESCE(b.available_copies,0) AS available_copies,
            COUNT(DISTINCT l.member_id)::int AS similar_reader_count,
            COUNT(l.id)::int AS borrow_count
        FROM loans l
        JOIN similar_members sm ON sm.member_id=l.member_id
        JOIN books b ON b.id=l.book_id
        WHERE b.id NOT IN (SELECT book_id FROM mine)
        GROUP BY b.id
        ORDER BY similar_reader_count DESC, borrow_count DESC, b.title ASC
        LIMIT %s
        ''',
        (member_id, member_id, limit),
    ) if history else []

    similar_readers = []
    for book in similar_rows:
        item = serialize_book(
            book,
            score=float(book.get('similar_reader_count') or 0),
            reason='Readers with overlapping borrowing interests also borrowed this title',
        )
        item['similar_reader_count'] = int(book.get('similar_reader_count') or 0)
        item['borrow_count'] = int(book.get('borrow_count') or 0)
        similar_readers.append(item)

    category_counts = Counter(
        str(book.get('category') or '').strip()
        for book in history
        if str(book.get('category') or '').strip()
    )
    author_counts = Counter(
        str(book.get('author') or '').strip()
        for book in history
        if str(book.get('author') or '').strip()
    )

    return {
        'member': member,
        'method': base.get('method', ''),
        'history_count': int(base.get('history_count') or len(history)),
        'taste': {
            'categories': [name for name, _ in category_counts.most_common(4)],
            'authors': [name for name, _ in author_counts.most_common(3)],
        },
        'personalised': personalised,
        'popular_now': popular_now,
        'highly_recommended': highly_recommended,
        'because_you_borrowed': because_you_borrowed,
        'similar_readers': similar_readers,
    }
