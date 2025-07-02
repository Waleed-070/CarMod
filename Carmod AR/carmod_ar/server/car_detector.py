import os
import torch
from PIL import Image
import io
import numpy as np
from ultralytics import YOLO
from ultralytics.nn.tasks import DetectionModel
import logging
import time

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("car_detector")

class CarDetector:
    def __init__(self):
        # Get the absolute path to the model file
        self.model_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'models', 'car_parts_detector.pt')
        logger.info(f"Initializing car detector with model at: {self.model_path}")
        
        # Add DetectionModel to safe globals
        torch.serialization.add_safe_globals([DetectionModel])
        
        # Load the model
        try:
            self.model = YOLO(self.model_path, task='detect')
            logger.info(f"Model loaded successfully")
            logger.info(f"Model classes: {self.model.names}")
        except Exception as e:
            logger.error(f"Error loading model: {e}")
            raise
    
    def detect_car(self, image_data):
        """
        Detect if the image contains a car and identify car parts
        
        Args:
            image_data: Binary image data or file path
            
        Returns:
            dict: Detection results with confidence scores
        """
        start_time = time.time()
        
        try:
            # Handle different input types
            if isinstance(image_data, bytes):
                image = Image.open(io.BytesIO(image_data))
                logger.info(f"Loaded image from bytes, size: {image.size}")
            elif isinstance(image_data, str):
                image = Image.open(image_data)
                logger.info(f"Loaded image from path: {image_data}, size: {image.size}")
            else:
                logger.error(f"Unsupported image data type: {type(image_data)}")
                return {"error": "Unsupported image data type"}
            
            # Run inference
            logger.info("Running model inference...")
            results = self.model(image)
            
            # Process predictions
            detections = []
            is_car = False
            
            for result in results:
                boxes = result.boxes
                for box in boxes:
                    # Get box coordinates
                    x1, y1, x2, y2 = box.xyxy[0].tolist()
                    confidence = float(box.conf[0])
                    class_id = int(box.cls[0])
                    class_name = result.names[class_id]
                    
                    # Check if this is a car part (assuming all detected parts are car parts)
                    if confidence > 0.5:  # Confidence threshold
                        is_car = True
                        detection = {
                            "bbox": [x1, y1, x2, y2],
                            "confidence": confidence,
                            "class_id": class_id,
                            "class_name": class_name
                        }
                        detections.append(detection)
            
            elapsed_time = time.time() - start_time
            logger.info(f"Detection completed in {elapsed_time:.2f} seconds")
            logger.info(f"Found {len(detections)} car parts")
            
            return {
                "status": "success",
                "is_car": is_car,
                "detections": detections,
                "total_detections": len(detections),
                "processing_time_ms": int(elapsed_time * 1000)
            }
            
        except Exception as e:
            elapsed_time = time.time() - start_time
            logger.error(f"Error during detection: {e}")
            return {
                "status": "error",
                "error": str(e),
                "processing_time_ms": int(elapsed_time * 1000)
            }

# Test the detector if run directly
if __name__ == "__main__":
    detector = CarDetector()
    
    # Test with a sample image if provided
    test_image_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'test_images', 'car_test.jpg')
    if os.path.exists(test_image_path):
        logger.info(f"Testing with image: {test_image_path}")
        result = detector.detect_car(test_image_path)
        logger.info(f"Test result: {result}")
    else:
        logger.info(f"No test image found at {test_image_path}")
        logger.info("Create a 'test_images' folder with a 'car_test.jpg' file to test the detector") 