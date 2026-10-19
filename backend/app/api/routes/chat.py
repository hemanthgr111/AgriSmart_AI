"""AI farmer assistant chat endpoint."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from app.api.deps import require_ai_access
from app.core.rate_limit import CHAT_RATE_LIMIT, limiter
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.ai import AIError, active_provider, generate_reply

router = APIRouter(prefix="/chat", tags=["assistant"])


@router.post("", response_model=ChatResponse)
@limiter.limit(CHAT_RATE_LIMIT)
async def chat(
    request: Request,
    payload: ChatRequest,
    _auth: None = Depends(require_ai_access),
) -> ChatResponse:
    """Send a conversation to the configured AI provider and return its reply.

    The provider and API key are configured server-side. If no provider is set,
    the endpoint returns 503 rather than inventing an answer.
    """
    try:
        reply = await generate_reply(payload.messages, locale=payload.locale)
    except AIError as error:
        raise HTTPException(status_code=error.status_code, detail=error.message)
    return ChatResponse(reply=reply, provider=active_provider())
