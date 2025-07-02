# Car Parts Detection Server

This server provides an API for detecting car parts in images using a YOLOv8 model.

## Setup

1. Install the required dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Make sure the model file `car_parts_detector.pt` is in the `models` directory.

3. Update the `kBaseUrl` in the Flutter app's `lib/utils/constants.dart` file to match your server's IP address:
   - For Android emulator: `http://10.0.2.2:8000`
   - For physical devices: `http://YOUR_COMPUTER_IP:8000`

## Running the Server

Start the server with:
```
python main.py
```

The server will run on port 8000 by default. You can access the API documentation at `http://localhost:8000/docs`.

## Testing the Detector

You can test the car detector without running the full server:

1. Place test images in the `test_images` directory.
2. Run the test script:
   ```
   python test_detector.py
   ```

Or specify a specific image to test:
```
python test_detector.py path/to/your/image.jpg
```

## API Endpoints

- `GET /`: API information
- `GET /health`: Health check
- `GET /model-info`: Information about the loaded model
- `POST /detect`: Detect car parts in an uploaded image

## Response Format

The `/detect` endpoint returns a JSON response with the following structure:

```json
{
  "status": "success",
  "is_car": true,
  "detections": [
    {
      "bbox": [x1, y1, x2, y2],
      "confidence": 0.95,
      "class_id": 0,
      "class_name": "headlight"
    }
  ],
  "total_detections": 1,
  "processing_time_ms": 120,
  "timestamp": "2023-08-01T12:34:56.789Z"
}
``` 