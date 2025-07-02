import os
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import torch
import torchvision.transforms as transforms
from PIL import Image
import io
import numpy as np
import json
from ultralytics import YOLO
from ultralytics.nn.tasks import DetectionModel
from datetime import datetime
import logging
from car_detector import CarDetector

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("car_detection_api")

app = FastAPI(
    title="Car Parts Detection API",
    description="API for detecting car parts using YOLOv8 model",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the car detector
try:
    car_detector = CarDetector()
    logger.info("Car detector initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize car detector: {e}")
    raise

@app.get("/")
async def root():
    """Root endpoint that returns API information"""
    return {
        "status": "online",
        "message": "Car Parts Detection API is running",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "endpoints": {
            "health": "/health",
            "detect": "/detect",
            "model_info": "/model-info"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint to verify API status"""
    return {
        "status": "healthy",
        "model_loaded": hasattr(car_detector, 'model'),
        "timestamp": datetime.now().isoformat()
    }

@app.get("/model-info")
async def model_info():
    """Get information about the loaded model"""
    return {
        "model_type": "YOLOv8",
        "model_path": car_detector.model_path,
        "model_size": f"{os.path.getsize(car_detector.model_path) / (1024*1024):.2f} MB",
        "device": str(car_detector.model.device),
        "classes": car_detector.model.names
    }

@app.post("/detect")
async def detect_parts(file: UploadFile = File(...)):
    """Detect car parts in an uploaded image"""
    try:
        logger.info(f"Received image: {file.filename}, content_type: {file.content_type}")
        
        # Read image
        contents = await file.read()
        
        # Process the image with our car detector
        result = car_detector.detect_car(contents)
        
        if result.get("status") == "error":
            logger.error(f"Error in car detection: {result.get('error')}")
            return JSONResponse(
                status_code=500,
                content={
                    "status": "error",
                    "message": result.get("error"),
                    "timestamp": datetime.now().isoformat()
                }
            )
        
        # Add timestamp to the result
        result["timestamp"] = datetime.now().isoformat()
        
        return result
        
    except Exception as e:
        logger.error(f"Error processing image: {e}")
        return JSONResponse(
            status_code=500,
            content={
                "status": "error",
                "message": str(e),
                "timestamp": datetime.now().isoformat()
            }
        )

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting Car Parts Detection API server...")
    logger.info("API Documentation available at: http://0.0.0.0:5000/docs")
    uvicorn.run(app, host="0.0.0.0", port=5000, log_level="info") 