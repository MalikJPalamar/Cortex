from fastapi import APIRouter
from api.mock_data import (
    create_ai_operation,
    get_operation_by_id,
    trigger_pipeline,
    update_settings
)
# Real Centaurion state (reads committed routing-log/ratings/dev-loop/workflows).
from api.live_data import (
    get_dashboard_stats,
    get_health_status,
    get_live_status,
    get_ai_operations,
    get_market_intelligence,
    generate_report,
    get_pipelines,
    get_settings,
)

router = APIRouter()

@router.get("/dashboard/stats")
async def dashboard_stats():
    return get_dashboard_stats()

@router.get("/status/live")
async def status_live():
    return get_live_status()

@router.get("/ai-operations")
async def list_ai_operations():
    return get_ai_operations()

@router.post("/ai-operations")
async def create_operation(operation: dict):
    return create_ai_operation(operation)

@router.get("/ai-operations/{operation_id}")
async def get_operation(operation_id: str):
    return get_operation_by_id(operation_id)

@router.get("/market/intelligence")
async def market_intelligence():
    return get_market_intelligence()

@router.post("/market/generate")
async def create_report(request: dict):
    return generate_report(request)

@router.get("/cicd/pipelines")
async def list_pipelines():
    return get_pipelines()

@router.post("/cicd/trigger")
async def trigger_cicd(request: dict):
    return trigger_pipeline(request)

@router.get("/cicd/health")
async def health():
    return get_health_status()

@router.get("/settings")
async def settings():
    return get_settings()

@router.put("/settings")
async def save_settings(settings_data: dict):
    return update_settings(settings_data)
