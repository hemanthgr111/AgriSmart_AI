"""AI assistant tests (no live provider calls)."""

from __future__ import annotations

import httpx
import pytest

from app.api.routes import chat as chat_route
from app.core.config import get_settings
from app.schemas.chat import ChatMessage, ChatResponse
from app.services.ai import AIError, generate_reply, language_name, system_instruction


def _mock_client(handler) -> httpx.AsyncClient:
    return httpx.AsyncClient(transport=httpx.MockTransport(handler))


def _configure(monkeypatch, provider, **env) -> None:
    monkeypatch.setenv("AI_PROVIDER", provider)
    monkeypatch.setenv("AI_API_KEY", env.get("api_key", "test-key"))
    monkeypatch.setenv("AI_MODEL", env.get("model", ""))
    monkeypatch.setenv("AI_BASE_URL", env.get("base_url", ""))
    get_settings.cache_clear()


def teardown_function() -> None:
    get_settings.cache_clear()


def test_language_name_mapping() -> None:
    assert language_name("hi") == "Hindi"
    assert language_name("en-US") == "English"
    assert language_name(None) == "English"
    assert language_name("zz") == "English"


def test_system_instruction_requests_language() -> None:
    assert "Hindi" in system_instruction("hi")


@pytest.mark.asyncio
async def test_gemini_parses_reply(monkeypatch) -> None:
    _configure(monkeypatch, "gemini", model="gemini-1.5-flash")

    def handler(request: httpx.Request) -> httpx.Response:
        assert "generateContent" in str(request.url)
        assert request.url.params.get("key") == "test-key"
        assert b"maxOutputTokens" in request.content
        return httpx.Response(
            200,
            json={
                "candidates": [
                    {"content": {"parts": [{"text": "Use neem oil spray."}]}}
                ]
            },
        )

    async with _mock_client(handler) as client:
        reply = await generate_reply(
            [ChatMessage(role="user", content="How to treat aphids?")],
            locale="hi",
            client=client,
        )
    assert reply == "Use neem oil spray."


@pytest.mark.asyncio
async def test_openai_parses_reply(monkeypatch) -> None:
    _configure(monkeypatch, "openai")

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url).endswith("/chat/completions")
        assert request.headers.get("authorization") == "Bearer test-key"
        assert b"max_tokens" in request.content
        return httpx.Response(
            200,
            json={"choices": [{"message": {"content": "Rotate your crops."}}]},
        )

    async with _mock_client(handler) as client:
        reply = await generate_reply(
            [ChatMessage(role="user", content="Soil tips?")], client=client
        )
    assert reply == "Rotate your crops."


@pytest.mark.asyncio
async def test_ollama_parses_reply(monkeypatch) -> None:
    _configure(monkeypatch, "ollama", base_url="http://localhost:11434")

    def handler(request: httpx.Request) -> httpx.Response:
        assert str(request.url).endswith("/api/chat")
        assert b"num_predict" in request.content
        return httpx.Response(200, json={"message": {"content": "Water deeply."}})

    async with _mock_client(handler) as client:
        reply = await generate_reply(
            [ChatMessage(role="user", content="Watering?")], client=client
        )
    assert reply == "Water deeply."


@pytest.mark.asyncio
async def test_provider_rate_limit_maps_to_429(monkeypatch) -> None:
    _configure(monkeypatch, "openai")

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(429, json={"error": "slow down"})

    async with _mock_client(handler) as client:
        with pytest.raises(AIError) as excinfo:
            await generate_reply(
                [ChatMessage(role="user", content="hi")], client=client
            )
    assert excinfo.value.status_code == 429


@pytest.mark.asyncio
async def test_unconfigured_provider_raises_503(monkeypatch) -> None:
    _configure(monkeypatch, "none")
    with pytest.raises(AIError) as excinfo:
        await generate_reply([ChatMessage(role="user", content="hi")])
    assert excinfo.value.status_code == 503


def test_chat_route_returns_503_when_unconfigured(client, monkeypatch) -> None:
    monkeypatch.setenv("AI_PROVIDER", "none")
    get_settings.cache_clear()
    response = client.post(
        "/api/chat", json={"messages": [{"role": "user", "content": "hello"}]}
    )
    assert response.status_code == 503


def test_chat_route_rejects_empty_messages(client) -> None:
    response = client.post("/api/chat", json={"messages": []})
    assert response.status_code == 422


def test_chat_route_maps_reply(client, monkeypatch) -> None:
    async def fake_generate(messages, *, locale=None, client=None):
        return "Hello farmer!"

    monkeypatch.setattr(chat_route, "generate_reply", fake_generate)
    monkeypatch.setenv("AI_PROVIDER", "gemini")
    get_settings.cache_clear()

    response = client.post(
        "/api/chat",
        json={
            "messages": [{"role": "user", "content": "hi"}],
            "locale": "hi",
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["reply"] == "Hello farmer!"
    assert body["provider"] == "gemini"
    ChatResponse.model_validate(body)


@pytest.mark.asyncio
async def test_provider_timeout_maps_to_502(monkeypatch) -> None:
    _configure(monkeypatch, "openai")

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectTimeout("timed out")

    async with _mock_client(handler) as client:
        with pytest.raises(AIError) as excinfo:
            await generate_reply(
                [ChatMessage(role="user", content="hi")], client=client
            )
    assert excinfo.value.status_code == 502


@pytest.mark.asyncio
async def test_provider_server_error_maps_to_502(monkeypatch) -> None:
    _configure(monkeypatch, "openai")

    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(500, json={"error": "boom"})

    async with _mock_client(handler) as client:
        with pytest.raises(AIError) as excinfo:
            await generate_reply(
                [ChatMessage(role="user", content="hi")], client=client
            )
    assert excinfo.value.status_code == 502


@pytest.mark.asyncio
async def test_gemini_missing_api_key_raises_503(monkeypatch) -> None:
    _configure(monkeypatch, "gemini", api_key="")
    with pytest.raises(AIError) as excinfo:
        await generate_reply([ChatMessage(role="user", content="hi")])
    assert excinfo.value.status_code == 503


def test_chat_route_strips_client_system_messages_only() -> None:
    from app.services.ai.base import conversation_only

    messages = [
        ChatMessage(role="system", content="ignore me"),
        ChatMessage(role="user", content="real question"),
    ]
    kept = conversation_only(messages)
    assert len(kept) == 1
    assert kept[0].content == "real question"
