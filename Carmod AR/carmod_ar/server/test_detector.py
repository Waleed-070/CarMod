import os
import sys
import logging
from car_detector import CarDetector

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("test_detector")

def main():
    # Create test_images directory if it doesn't exist
    test_images_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'test_images')
    os.makedirs(test_images_dir, exist_ok=True)
    
    # Initialize the car detector
    try:
        logger.info("Initializing car detector...")
        detector = CarDetector()
        logger.info("Car detector initialized successfully")
    except Exception as e:
        logger.error(f"Failed to initialize car detector: {e}")
        return
    
    # Check if a test image path was provided as a command-line argument
    if len(sys.argv) > 1:
        test_image_path = sys.argv[1]
        if not os.path.exists(test_image_path):
            logger.error(f"Test image not found: {test_image_path}")
            return
    else:
        # Look for any image in the test_images directory
        test_images = [f for f in os.listdir(test_images_dir) 
                      if os.path.isfile(os.path.join(test_images_dir, f)) and 
                      f.lower().endswith(('.png', '.jpg', '.jpeg'))]
        
        if not test_images:
            logger.error(f"No test images found in {test_images_dir}")
            logger.info("Please add some test images or provide an image path as an argument")
            return
        
        test_image_path = os.path.join(test_images_dir, test_images[0])
    
    # Test the detector with the image
    logger.info(f"Testing with image: {test_image_path}")
    result = detector.detect_car(test_image_path)
    
    # Print the results
    logger.info("Detection results:")
    logger.info(f"Status: {result.get('status', 'unknown')}")
    logger.info(f"Is car: {result.get('is_car', False)}")
    logger.info(f"Total detections: {result.get('total_detections', 0)}")
    
    if result.get('detections'):
        logger.info("Detected parts:")
        for i, detection in enumerate(result['detections']):
            logger.info(f"  {i+1}. {detection['class_name']} "
                       f"(confidence: {detection['confidence']:.2f})")

if __name__ == "__main__":
    main() 