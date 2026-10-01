"""Tiny data layer using SQLAlchemy Core (works with PostgreSQL in prod, SQLite in tests)."""
from sqlalchemy import Column, Float, Integer, MetaData, String, Table, create_engine, select, text, update

metadata = MetaData()
products = Table(
    "products",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("name", String(200), nullable=False),
    Column("price", Float, nullable=False),
    Column("stock", Integer, nullable=False, default=0),
)

SEED = [
    {"name": "Industrial Sensor", "price": 129.0, "stock": 50},
    {"name": "PLC Controller", "price": 899.0, "stock": 10},
    {"name": "Safety Helmet", "price": 39.5, "stock": 200},
]


class Database:
    def __init__(self, url: str):
        self.engine = create_engine(url, pool_pre_ping=True, future=True)

    def init(self):
        metadata.create_all(self.engine)
        with self.engine.begin() as c:
            if c.execute(select(products.c.id).limit(1)).first() is None:
                c.execute(products.insert(), SEED)

    def ping(self) -> bool:
        try:
            with self.engine.connect() as c:
                c.execute(text("SELECT 1"))
            return True
        except Exception:
            return False

    def list_products(self):
        with self.engine.connect() as c:
            return [dict(r._mapping) for r in c.execute(select(products).order_by(products.c.id))]

    def get_product(self, pid: int):
        with self.engine.connect() as c:
            r = c.execute(select(products).where(products.c.id == pid)).first()
            return dict(r._mapping) if r else None

    def create_product(self, name: str, price: float, stock: int):
        with self.engine.begin() as c:
            pid = c.execute(products.insert().values(name=name, price=price, stock=stock)).inserted_primary_key[0]
        return self.get_product(pid)

    def reserve(self, pid: int, qty: int):
        """Atomically decrement stock. Returns product, None if missing, False if not enough stock."""
        with self.engine.begin() as c:
            res = c.execute(
                update(products)
                .where(products.c.id == pid, products.c.stock >= qty)
                .values(stock=products.c.stock - qty)
            )
            if res.rowcount == 0:
                exists = c.execute(select(products.c.id).where(products.c.id == pid)).first()
                return False if exists else None
        return self.get_product(pid)
