#!/usr/bin/env python3
"""Generates a year of demo data in the CSV layout read by `CSVImporter`.

Run `python3 generate.py` and import every `.csv` file in this folder from
Settings. The output is deterministic, so re-running produces the same files.
"""

import random
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

random.seed(2026)

OUT = Path(__file__).parent
START = date(2025, 11, 1)
END = date(2026, 10, 29)
DAYS = (END - START).days + 1


def d(value) -> Decimal:
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def fmt_date(day: date) -> str:
    return day.strftime("%d.%m.%Y")


def fmt_amount(value: Decimal) -> str:
    return format(value.normalize(), "f")


def write(name: str, header: list[str], rows: list[list]):
    lines = [";".join(header)] + [";".join(str(v) for v in row) for row in rows]
    (OUT / name).write_text("\n".join(lines) + "\n", encoding="utf-8")


def days():
    for i in range(DAYS):
        yield START + timedelta(days=i)


# MARK: - Reference data

accounts = [
    ["Bank Card", "2450", "creditcard", "blue"],
    ["Cash", "120", "banknote", "green"],
    ["Savings", "6800", "building.columns", "indigo"],
]

categories = [
    ["Groceries", "expense", "cart", "green"],
    ["Restaurants", "expense", "fork.knife", "orange"],
    ["Transport", "expense", "car", "blue"],
    ["Housing", "expense", "house", "brown"],
    ["Utilities", "expense", "lightbulb", "yellow"],
    ["Health", "expense", "cross.case", "red"],
    ["Entertainment", "expense", "film", "purple"],
    ["Shopping", "expense", "bag", "pink"],
    ["Subscriptions", "expense", "tv", "indigo"],
    ["Other", "expense", "questionmark.circle", "gray"],
    ["Salary", "income", "briefcase", "green"],
    ["Freelance", "income", "laptopcomputer", "teal"],
    ["Gifts", "income", "gift", "pink"],
    ["Investments", "income", "chart.line.uptrend.xyaxis", "mint"],
]

budgets = [
    ["", "1600", "true"],
    ["Groceries", "380", "true"],
    ["Restaurants", "160", "true"],
    ["Entertainment", "90", "true"],
    ["Shopping", "200", "true"],
    ["Transport", "140", "true"],
]

collections = [
    ["Summer Trip", "airplane", "cyan"],
    ["Home Office", "desktopcomputer", "teal"],
]

expenses: list[dict] = []
incomes: list[dict] = []
transfers: list[dict] = []
receipt_items: list[list] = []
collection_links: list[list] = []
used_keys: set[tuple] = set()


def add_expense(day, amount, source, category, details, collection=None):
    amount = d(amount)
    # The importer links receipt items and collections by date, amount, account and
    # details, so each expense must be unique on those.
    while (day, amount, source, details) in used_keys:
        amount += Decimal("0.01")
    used_keys.add((day, amount, source, details))
    expenses.append(dict(date=day, amount=amount, source=source, category=category, details=details))
    if collection:
        collection_links.append([collection, fmt_date(day), "expense", fmt_amount(amount), source, "", details])
    return amount


# MARK: - Groceries with receipt items
#
# Each product follows a price path over the year (step increases, as shops do),
# with store markups and occasional promotions, so the Price Comparison screen
# shows a realistic personal inflation figure.

# name, base unit price, yearly change, chance per trip, quantity range, weighed
products = [
    ("Milk 2.8% 1L", 1.09, 0.08, 0.75, (1, 3), False),
    ("White Bread 500g", 1.29, 0.11, 0.65, (1, 2), False),
    ("Eggs M 10pcs", 2.49, 0.31, 0.40, (1, 1), False),
    ("Butter 250g", 2.79, 0.14, 0.30, (1, 1), False),
    ("Gouda Cheese 400g", 4.99, 0.09, 0.30, (1, 1), False),
    ("Greek Yogurt 400g", 1.69, 0.05, 0.45, (1, 3), False),
    ("Chicken Breast", 8.99, 0.06, 0.35, (0.45, 1.2), True),
    ("Bananas", 1.49, -0.04, 0.55, (0.8, 1.6), True),
    ("Apples", 1.79, 0.07, 0.40, (0.9, 2.0), True),
    ("Tomatoes", 2.49, 0.12, 0.35, (0.5, 1.2), True),
    ("Spaghetti 500g", 1.19, 0.00, 0.30, (1, 2), False),
    ("Basmati Rice 1kg", 2.89, 0.04, 0.20, (1, 1), False),
    ("Ground Coffee 500g", 6.49, 0.27, 0.25, (1, 1), False),
    ("Olive Oil 1L", 9.99, 0.18, 0.22, (1, 1), False),
    ("Dark Chocolate 100g", 1.59, 0.24, 0.35, (1, 2), False),
    ("Orange Juice 1L", 1.99, 0.16, 0.35, (1, 2), False),
    ("Sugar 1kg", 1.25, -0.09, 0.22, (1, 1), False),
    ("Toilet Paper 10 rolls", 4.49, 0.03, 0.18, (1, 1), False),
    ("Laundry Detergent 2L", 7.99, -0.03, 0.18, (1, 1), False),
    ("Mineral Water 1.5L", 0.59, 0.10, 0.45, (2, 6), False),
]

stores = [("Fresh Market", 1.00, 0.40), ("Value Discount", 0.96, 0.35), ("Corner Deli", 1.05, 0.25)]


def price_path(change: float):
    """Two to four step changes spread over the year that add up to `change`."""
    steps = random.randint(2, 4)
    points = sorted(random.sample(range(20, DAYS - 20), steps))
    weights = [random.random() + 0.3 for _ in points]
    total = sum(weights)
    path, factor = [], 1.0
    for point, weight in zip(points, weights):
        factor *= (1 + change) ** (weight / total)
        path.append((point, factor))
    return path


paths = {p[0]: price_path(p[2]) for p in products}


def unit_price(product, day, store_markup):
    name, base = product[0], product[1]
    offset = (day - START).days
    factor = 1.0
    for point, value in paths[name]:
        if offset >= point:
            factor = value
    price = base * factor * store_markup
    if name == "Tomatoes":
        # Cheaper in summer, pricier in winter.
        price *= 0.8 if day.month in (6, 7, 8, 9) else 1.1
    if random.random() < 0.05:
        price *= 0.85
    # Shelf prices end in .x4 or .x9.
    return max(d(round(price * 20) / 20 - 0.01), Decimal("0.29"))


for day in days():
    # A big shop on Saturdays and one or two smaller top-up trips during the week.
    trips = []
    if day.weekday() == 5:
        trips.append(True)
    elif day.weekday() in (1, 3) and random.random() < 0.6:
        trips.append(False)
    for big in trips:
        store, markup, _ = random.choices(stores, weights=[s[2] for s in stores])[0]
        bought = [p for p in products if random.random() < (p[3] if big else p[3] * 0.45)]
        if not bought:
            bought = [products[0], products[1]]
        lines, total = [], Decimal(0)
        for position, product in enumerate(bought):
            price = unit_price(product, day, markup)
            low, high = product[4]
            if product[5]:
                quantity = Decimal(str(round(random.uniform(low, high), 3)))
            else:
                quantity = Decimal(random.randint(int(low), int(high)))
            line_total = d(price * quantity)
            total += line_total
            lines.append([position, product[0], fmt_amount(quantity), fmt_amount(price), fmt_amount(line_total)])
        source = "Cash" if random.random() < 0.15 else "Bank Card"
        amount = add_expense(day, total, source, "Groceries", store)
        if amount != total:
            # Keep the receipt summing to the transaction amount.
            last = lines[-1]
            last[4] = fmt_amount(Decimal(last[4]) + amount - total)
        for line in lines:
            receipt_items.append([fmt_date(day), "expense", fmt_amount(amount), source, "", store] + line)


# MARK: - Other expenses

def monthly(day_of_month):
    for day in days():
        if day.day == day_of_month:
            yield day


for day in monthly(1):
    add_expense(day, 650, "Bank Card", "Housing", "Rent")
for day in monthly(15):
    winter = day.month in (11, 12, 1, 2, 3)
    add_expense(day, random.uniform(78, 96) if winter else random.uniform(42, 58), "Bank Card", "Utilities", "Electricity")
    add_expense(day, random.uniform(22, 31), "Bank Card", "Utilities", "Water")
for day in monthly(20):
    add_expense(day, 29.99, "Bank Card", "Utilities", "Internet")
    add_expense(day, 15, "Bank Card", "Utilities", "Mobile plan")
for day in monthly(5):
    add_expense(day, 13.99, "Bank Card", "Subscriptions", "StreamFlix")
    add_expense(day, 39, "Bank Card", "Health", "Gym membership")
for day in monthly(12):
    add_expense(day, 10.99, "Bank Card", "Subscriptions", "Music+")
    add_expense(day, 2.99, "Bank Card", "Subscriptions", "Cloud storage")
for day in monthly(3):
    add_expense(day, 39, "Bank Card", "Transport", "Monthly transit pass")
add_expense(date(2026, 2, 10), 420, "Bank Card", "Transport", "Car insurance")
add_expense(date(2026, 3, 2), 89.99, "Bank Card", "Subscriptions", "Cloud storage yearly upgrade")

restaurants = ["Pizzeria Napoli", "Sushi Bar Koi", "The Burger Joint", "Café Central", "Thai Garden", "Bistro 21"]
for day in days():
    weekend = day.weekday() >= 4
    if random.random() < (0.28 if weekend else 0.12):
        place = random.choice(restaurants)
        amount = random.uniform(6, 14) if place == "Café Central" else random.uniform(16, 48)
        add_expense(day, amount, "Cash" if random.random() < 0.25 else "Bank Card", "Restaurants", place)
    if day.weekday() < 5 and random.random() < 0.3:
        add_expense(day, random.choice([2.2, 2.4, 2.6, 3.1]), "Cash", "Restaurants", "Coffee to go")
    if random.random() < 0.06:
        add_expense(day, random.uniform(45, 70), "Bank Card", "Transport", "Fuel")
    if random.random() < 0.04:
        add_expense(day, random.uniform(7, 19), "Bank Card", "Transport", "Taxi")
    if random.random() < 0.05:
        add_expense(day, random.uniform(5, 35), "Bank Card", "Health", "Pharmacy")
    if weekend and random.random() < 0.08:
        what = random.choice(["Cinema", "Concert tickets", "Bowling", "Museum", "Board game cafe"])
        add_expense(day, random.uniform(9, 22) if what != "Concert tickets" else random.uniform(35, 70),
                    "Bank Card", "Entertainment", what)
    if random.random() < 0.05:
        what = random.choice(["Clothes", "Shoes", "Books", "Home decor", "Electronics accessories"])
        add_expense(day, random.uniform(15, 90), "Bank Card", "Shopping", what)
    if random.random() < 0.015:
        what = random.choice(["Haircut", "Post office", "Dry cleaning", "Charity donation"])
        add_expense(day, random.uniform(8, 25), "Cash", "Other", what)

# Seasonal and one-off purchases.
for day, amount, details in [
    (date(2025, 11, 28), 189, "Black Friday headphones"),
    (date(2025, 12, 14), 124.5, "Christmas gifts"),
    (date(2025, 12, 20), 86.3, "Christmas gifts"),
    (date(2026, 4, 18), 64.9, "Spring jacket"),
    (date(2026, 9, 12), 72, "Running shoes"),
]:
    add_expense(day, amount, "Bank Card", "Shopping", details)
add_expense(date(2025, 12, 31), 75, "Bank Card", "Entertainment", "New Year's Eve party")
add_expense(date(2026, 5, 6), 60, "Bank Card", "Health", "Dentist")

for day, amount, category, details in [
    (date(2026, 1, 24), 349, "Shopping", "Standing desk"),
    (date(2026, 1, 24), 219, "Shopping", "Office chair"),
    (date(2026, 1, 31), 179, "Shopping", "Monitor 27 inch"),
    (date(2026, 2, 7), 39.9, "Shopping", "Desk lamp"),
]:
    add_expense(day, amount, "Bank Card", category, details, collection="Home Office")

for day, amount, category, details in [
    (date(2026, 5, 20), 238, "Transport", "Flight tickets"),
    (date(2026, 7, 11), 412, "Housing", "Seaside apartment"),
    (date(2026, 7, 11), 54, "Transport", "Ferry"),
    (date(2026, 7, 12), 46.8, "Restaurants", "Konoba Ribar"),
    (date(2026, 7, 13), 35, "Entertainment", "Boat tour"),
    (date(2026, 7, 14), 61.2, "Restaurants", "Seafood dinner"),
    (date(2026, 7, 15), 28.5, "Shopping", "Souvenirs"),
    (date(2026, 7, 16), 22.4, "Restaurants", "Ice cream & drinks"),
    (date(2026, 7, 17), 40, "Transport", "Rental scooter"),
]:
    add_expense(day, amount, "Bank Card", category, details, collection="Summer Trip")


# MARK: - Incomes and transfers

for day in monthly(10):
    salary = 1850 if day < date(2026, 4, 1) else 1940
    incomes.append(dict(date=day, amount=d(salary), destination="Bank Card", category="Salary", details="Monthly salary"))
incomes.append(dict(date=date(2025, 12, 10), amount=d(900), destination="Bank Card", category="Salary", details="Christmas bonus"))
for day, amount, details in [
    (date(2025, 11, 22), 320, "Logo design"), (date(2026, 1, 17), 540, "Website redesign"),
    (date(2026, 3, 28), 280, "App icon set"), (date(2026, 6, 6), 610, "Landing page"),
    (date(2026, 9, 19), 450, "Brand guidelines"),
]:
    incomes.append(dict(date=day, amount=d(amount), destination="Bank Card", category="Freelance", details=details))
for day, amount, details in [(date(2025, 12, 25), 100, "Christmas gift"), (date(2026, 8, 3), 150, "Birthday gift")]:
    incomes.append(dict(date=day, amount=d(amount), destination="Cash", category="Gifts", details=details))
for day in [date(2025, 12, 31), date(2026, 3, 31), date(2026, 6, 30), date(2026, 9, 30)]:
    incomes.append(dict(date=day, amount=d(random.uniform(38, 55)), destination="Savings", category="Investments", details="ETF dividends"))

for day in monthly(11):
    transfers.append(dict(date=day, amount=d(300), source="Bank Card", target="Savings", details="Monthly savings"))
for day in days():
    if day.weekday() == 4 and random.random() < 0.4:
        transfers.append(dict(date=day, amount=d(random.choice([50, 60, 80, 100])), source="Bank Card", target="Cash", details="ATM withdrawal"))
transfers.append(dict(date=date(2026, 6, 25), amount=d(500), source="Savings", target="Bank Card", details="Trip money"))

planned = [
    ["expense", "650", "Bank Card", "", "Housing", "monthly", "1", "01.11.2025", "", "false", "Rent"],
    ["expense", "13.99", "Bank Card", "", "Subscriptions", "monthly", "1", "05.11.2025", "", "false", "StreamFlix"],
    ["expense", "39", "Bank Card", "", "Health", "monthly", "1", "05.11.2025", "", "false", "Gym membership"],
    ["expense", "29.99", "Bank Card", "", "Utilities", "monthly", "1", "20.11.2025", "", "false", "Internet"],
    ["expense", "420", "Bank Card", "", "Transport", "yearly", "1", "10.02.2026", "", "false", "Car insurance"],
    ["income", "1940", "", "Bank Card", "Salary", "monthly", "1", "10.04.2026", "", "false", "Monthly salary"],
    ["transfer", "300", "Bank Card", "Savings", "", "monthly", "1", "11.11.2025", "", "false", "Monthly savings"],
]


# MARK: - Output

def by_date(rows):
    return sorted(rows, key=lambda r: r["date"])


write("accounts.csv", ["name", "initial_value", "icon", "color"], accounts)
write("categories.csv", ["name", "kind", "icon", "color"], categories)
write("expenses.csv", ["date", "amount", "source", "category", "details"],
      [[fmt_date(r["date"]), fmt_amount(r["amount"]), r["source"], r["category"], r["details"]] for r in by_date(expenses)])
write("incomes.csv", ["date", "amount", "destination", "category", "details"],
      [[fmt_date(r["date"]), fmt_amount(r["amount"]), r["destination"], r["category"], r["details"]] for r in by_date(incomes)])
write("transfers.csv", ["date", "amount", "source", "target", "details"],
      [[fmt_date(r["date"]), fmt_amount(r["amount"]), r["source"], r["target"], r["details"]] for r in by_date(transfers)])
write("planned_transactions.csv", ["kind", "amount", "source", "destination", "category", "frequency",
                                   "interval", "start_date", "end_date", "paused", "details"], planned)
write("budgets.csv", ["category", "limit", "active"], budgets)
write("collections.csv", ["name", "icon", "color"], collections)
reference = ["transaction_date", "transaction_kind", "transaction_amount",
             "transaction_source", "transaction_destination", "transaction_details"]
write("collection_transactions.csv", ["collection"] + reference, collection_links)
write("receipt_items.csv", reference + ["position", "name", "quantity", "unit_price", "total_price"], receipt_items)

# Summary, mirroring PriceHistory's first-3 / last-3 average.
print(f"{len(expenses)} expenses, {len(incomes)} incomes, {len(transfers)} transfers, {len(receipt_items)} receipt items")
changes = []
for name, *_ in products:
    prices = [Decimal(r[9]) for r in receipt_items if r[7] == name]
    start, end = sum(prices[:3]) / 3, sum(prices[-3:]) / 3
    change = float((end - start) / start)
    changes.append(change)
    flag = "" if len(prices) >= 11 else "  (below 11 purchases, not tracked)"
    print(f"  {name:<24} {len(prices):>3} purchases  {change:+.1%}{flag}")
print(f"Personal inflation ≈ {sum(changes) / len(changes):+.1%}")
