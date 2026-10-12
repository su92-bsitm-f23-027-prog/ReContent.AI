"""Source analysis and platform-aware content generation."""
import json
import re

from django.conf import settings
from rest_framework.exceptions import APIException


class AIUnavailable(APIException):
    status_code = 503
    default_detail = "AI generation is not configured."
    default_code = "ai_unavailable"


def _openai_text(instructions, text):
    if not settings.OPENAI_API_KEY or not settings.OPENAI_MODEL:
        raise AIUnavailable("Set OPENAI_API_KEY and OPENAI_MODEL in backend/.env to enable provider AI.")
    try:
        from openai import OpenAI
        response = OpenAI(api_key=settings.OPENAI_API_KEY).responses.create(
            model=settings.OPENAI_MODEL,
            instructions=instructions,
            input=text[:30000],
        )
        return response.output_text.strip()
    except AIUnavailable:
        raise
    except Exception as exc:
        raise AIUnavailable("The AI provider request failed. Check your key, model, and account limits.") from exc


def _json_from_text(text):
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        start, end = text.find("{"), text.rfind("}")
        if start >= 0 and end > start:
            try:
                return json.loads(text[start:end + 1])
            except json.JSONDecodeError:
                pass
    raise AIUnavailable("The AI provider returned an unreadable response. Please try again.")


def analyze_source_text(text):
    if settings.AI_MODE == "openai":
        raw = _openai_text(
            "Analyze the source. Return only JSON with topic (string), summary (string), key_points (array of strings), and important_ideas (array of strings).",
            text,
        )
        data = _json_from_text(raw)
        return {
            "topic": str(data.get("topic", ""))[:300],
            "summary": str(data.get("summary", "")),
            "key_points": list(data.get("key_points", []))[:8],
            "important_ideas": list(data.get("important_ideas", []))[:8],
        }
    sentences = [part.strip() for part in re.split(r"(?<=[.!?])\s+", text) if part.strip()]
    words = text.split()
    return {
        "topic": " ".join(words[:8]).strip(".,:;!?"),
        "summary": " ".join(words[:45]) + ("…" if len(words) > 45 else ""),
        "key_points": sentences[:5] or [text[:240]],
        "important_ideas": sentences[:3] or [text[:240]],
    }


def _demo_content(text, platform, content_type):
    clean = " ".join(text.split())
    excerpt = clean[:240].rstrip(" .,;:")
    if platform == "linkedin":
        lead = "A practical idea worth sharing:"
        hashtags = "#Leadership #Learning #Ideas"
    elif platform == "instagram":
        lead = "Save this idea for later ✨"
        hashtags = "#CreatorTips #Inspiration #LearnSomething"
    else:
        lead = "Here’s an idea to share with your community:"
        hashtags = "#Community #Ideas #Learn"
    templates = {
        "caption": f"{lead}\n\n{excerpt}\n\nWhat would you add?",
        "hook": f"What if one small change could make a real difference?\n\n{excerpt[:150]}",
        "title": "A fresh perspective on " + " ".join(clean.split()[:7]).rstrip(".,!?"),
        "description": f"A concise take on the key ideas:\n\n{excerpt}",
        "hashtags": hashtags,
        "short_post": f"{lead} {excerpt[:170]}",
    }
    return templates[content_type]


def generate_text(text, platform, content_type):
    if settings.AI_MODE == "openai":
        platform_guidance = {
            "instagram": "Keep it visual, concise, and conversational. Lead with a strong hook and use a few relevant hashtags when appropriate.",
            "facebook": "Use a warm, community-oriented voice and invite a response. Keep paragraphs easy to scan.",
            "linkedin": "Use a professional, insight-led voice. Prefer clear short paragraphs and avoid slang or hashtag overload.",
        }[platform]
        instructions = (
            "Write one polished social media item for " + platform + ". " + platform_guidance + " "
            "Return only the requested content, with no labels or explanation. Content type: " + content_type + "."
        )
        return _openai_text(instructions, text)
    return _demo_content(text, platform, content_type)


def generate_variants(text, platform, content_types):
    """Generate one platform's requested types in a single provider call."""
    if settings.AI_MODE != "openai":
        return {content_type: _demo_content(text, platform, content_type) for content_type in content_types}
    platform_guidance = {
        "instagram": "visual, concise, conversational, with a strong hook and a few relevant hashtags when appropriate",
        "facebook": "warm and community-oriented, with an invitation to respond and paragraphs that scan easily",
        "linkedin": "professional and insight-led, with clear short paragraphs and no slang or hashtag overload",
    }[platform]
    keys = ", ".join(f'"{item}"' for item in content_types)
    instructions = (
        f"Create platform-specific social content for {platform}. Use this tone guidance: {platform_guidance}. "
        f"Return only a JSON object with exactly these keys: {keys}. Each value must be a string containing that format."
    )
    data = _json_from_text(_openai_text(instructions, text))
    output = {}
    for content_type in content_types:
        value = data.get(content_type)
        if not isinstance(value, str) or not value.strip():
            raise AIUnavailable("The AI provider missed one of the requested content formats. Please try again.")
        output[content_type] = value.strip()
    return output
