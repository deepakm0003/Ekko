"""Groq fallback: request shape, output sanitising, fail-soft, and wiring into the advisor."""
import json

import httpx

from app import ai


class FakeResponse:
    def __init__(self, payload, status=200):
        self.payload, self.status_code = payload, status
        self.text = json.dumps(payload)

    def raise_for_status(self):
        if self.status_code >= 400:
            raise httpx.HTTPStatusError("err", request=None, response=None)

    def json(self):
        return self.payload


def test_groq_request_shape_and_json_mode(monkeypatch):
    seen = {}

    def fake_post(url, json, timeout, headers):  # noqa: A002 - mirrors httpx.post
        seen.update(url=url, body=json, auth=headers["Authorization"])
        return FakeResponse({"choices": [{"message": {"content": '{"employees": 3}'}}]})

    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    monkeypatch.setattr(ai.httpx, "post", fake_post)
    assert ai._groq("sys", "user", json_mode=True, max_tokens=50) == '{"employees": 3}'
    assert seen["url"] == ai.GROQ_URL and seen["auth"] == "Bearer gsk_test"
    assert seen["body"]["response_format"] == {"type": "json_object"} and seen["body"]["temperature"] == 0


def test_groq_failure_returns_none(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", "gsk_test")
    monkeypatch.setattr(ai.httpx, "post", lambda *a, **k: FakeResponse({}, status=429))
    assert ai._groq("sys", "user", json_mode=False, max_tokens=10) is None

    def boom(*a, **k):
        raise httpx.ConnectTimeout("slow")

    monkeypatch.setattr(ai.httpx, "post", boom)
    assert ai._groq("sys", "user", json_mode=False, max_tokens=10) is None


def test_model_output_is_sanitised():
    hostile = {"employees": "12", "sites": 99999, "needs": ["cctv", "free_internet"], "discount": 90,
               "currentInternet": "Starlink", "cityTier": 3, "gstin": "27xuixg0767d1zp", "noGstin": "yes",
               "businessType": "Dental clinic" + "x" * 200}
    out = ai.sanitise(hostile)
    assert out == {"employees": 12, "needs": ["cctv"], "gstin": "27XUIXG0767D1ZP", "businessType": out["businessType"]}
    assert len(out["businessType"]) == 60 and "discount" not in out


def test_advisor_uses_llm_only_when_rules_miss(client, monkeypatch):
    calls = []
    monkeypatch.setattr(ai, "_call", lambda *a, **k: calls.append(a) or json.dumps({"employees": 18}))
    r = client.post("/v1/advisor/understand", json={"step": "employees", "text": "hum teen log hain"}).json()
    assert r["source"] == "rules" and not calls  # rules handled it; no LLM call
    r = client.post("/v1/advisor/understand", json={"step": "employees", "text": "staff thoda zyada hai, around eighteen"}).json()
    assert r == {"fields": {"employees": 18}, "source": "ai"} and len(calls) == 1


def test_retired_model_switches_to_an_available_one(monkeypatch):
    monkeypatch.setenv("GROQ_API_KEY", " gsk_test \n")
    monkeypatch.setattr(ai, "_groq_model", None)
    used, auths = [], []

    def fake_post(url, json, timeout, headers):  # noqa: A002
        used.append(json["model"])
        auths.append(headers["Authorization"])
        if json["model"] == ai.settings.groq_model:
            return FakeResponse({"error": {"message": "The model has been decommissioned", "code": "model_decommissioned"}}, 400)
        return FakeResponse({"choices": [{"message": {"content": "OK"}}]})

    monkeypatch.setattr(ai.httpx, "post", fake_post)
    monkeypatch.setattr(ai.httpx, "get", lambda *a, **k: FakeResponse(
        {"data": [{"id": "whisper-large-v3"}, {"id": "openai/gpt-oss-120b"}, {"id": "llama-3.1-8b-instant"}]}))
    assert ai._groq("s", "u", json_mode=False, max_tokens=5) == "OK"
    assert used == [ai.settings.groq_model, "openai/gpt-oss-120b"] and ai._groq_model == "openai/gpt-oss-120b"
    assert set(auths) == {"Bearer gsk_test"}  # key whitespace stripped
