import os
import tempfile

# Isolated database and fast tracker stages before the app is imported.
_tmp = tempfile.mkdtemp(prefix="ekko-test-")
os.environ["EKKO_DATABASE_URL"] = f"sqlite:///{_tmp}/test.db"
os.environ["EKKO_RATE_PER_MIN"] = "10000"
os.environ["EKKO_STAGE_SECONDS"] = "3600,7200,10800"
os.environ.pop("ANTHROPIC_API_KEY", None)

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

PHONES = iter(f"98{n:08d}" for n in range(10_000_000, 99_999_999, 7919))


@pytest.fixture(scope="session")
def client():
    return TestClient(app)


def login_owner(client) -> dict:
    phone = next(PHONES)
    otp = client.post("/v1/auth/otp/request", json={"phone": phone}).json()["demoOtp"]
    tok = client.post("/v1/auth/otp/verify", json={"phone": phone, "otp": otp}).json()["accessToken"]
    return {"Authorization": f"Bearer {tok}"}


def login_partner(client) -> dict:
    tok = client.post("/v1/auth/partner", json={"partnerId": "PTR-1001", "pin": "482916"}).json()["accessToken"]
    return {"Authorization": f"Bearer {tok}"}


@pytest.fixture
def owner(client):
    return login_owner(client)


@pytest.fixture
def partner(client):
    return login_partner(client)
