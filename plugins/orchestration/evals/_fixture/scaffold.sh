#!/usr/bin/env bash
# Builds the small multi-module Python repository the delegation evals ask about.
# It runs in the case's working directory.
set -euo pipefail

mkdir -p src/billing src/api src/jobs src/reports src/shared tests

cat > pyproject.toml <<'PY'
[project]
name = "ledger"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["langgraph==1.0.3"]
PY

cat > src/shared/money.py <<'PY'
from decimal import Decimal, ROUND_HALF_EVEN


class Money:
    def __init__(self, amount: Decimal) -> None:
        self.amount = amount

    def quantize(self, places: int = 2) -> "Money":
        return Money(self.amount.quantize(Decimal(1).scaleb(-places), rounding=ROUND_HALF_EVEN))
PY

cat > src/billing/tax.py <<'PY'
from decimal import Decimal

from src.shared.money import Money


def compute_tax(net: Money, rate: float) -> Money:
    return Money(net.amount * Decimal(str(rate))).quantize()
PY

cat > src/billing/invoice.py <<'PY'
from src.billing.tax import compute_tax
from src.shared.money import Money


def invoice_total(net: Money, rate: float) -> Money:
    return Money(net.amount + compute_tax(net, rate).amount).quantize(2)
PY

cat > src/billing/export.py <<'PY'
from src.billing.invoice import invoice_total
from src.shared.money import Money


def export_row(net: Money, rate: float) -> dict[str, str]:
    return {"total": str(invoice_total(net, rate).quantize(2).amount)}
PY

cat > src/api/routes.py <<'PY'
from src.billing.invoice import invoice_total
from src.billing.tax import compute_tax
from src.shared.money import Money


def get_invoice(net: str, rate: float) -> dict[str, str]:
    money = Money.__new__(Money)
    return {"tax": str(compute_tax(money, rate).amount), "total": str(invoice_total(money, rate).amount)}
PY

cat > src/jobs/nightly.py <<'PY'
from src.billing.export import export_row
from src.jobs.retry import with_retry
from src.shared.money import Money


def run(rows: list[tuple[Money, float]]) -> list[dict[str, str]]:
    return [with_retry(lambda: export_row(net, rate)) for net, rate in rows]
PY

cat > src/jobs/retry.py <<'PY'
def with_retry(fn, attempts: int = 3):
    for _ in range(attempts - 1):
        try:
            return fn()
        except Exception:
            continue
    return fn()
PY

cat > src/reports/monthly.py <<'PY'
from src.billing.tax import compute_tax
from src.shared.money import Money


def tax_due(nets: list[Money], rate: float) -> Money:
    return Money(sum((compute_tax(n, rate).amount for n in nets))).quantize(2)
PY

cat > tests/test_tax.py <<'PY'
from decimal import Decimal

from src.billing.tax import compute_tax
from src.shared.money import Money


def test_compute_tax():
    assert compute_tax(Money(Decimal("100")), 0.19).amount == Decimal("19.00")
PY

cat > tests/test_invoice.py <<'PY'
from decimal import Decimal

from src.billing.invoice import invoice_total
from src.shared.money import Money


def test_total():
    assert invoice_total(Money(Decimal("100")), 0.19).amount == Decimal("119.00")
PY

touch src/__init__.py src/billing/__init__.py src/api/__init__.py src/jobs/__init__.py src/reports/__init__.py src/shared/__init__.py
