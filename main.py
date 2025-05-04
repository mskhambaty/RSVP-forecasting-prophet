from fastapi import FastAPI, HTTPException
import pickle
import pandas as pd
from prophet import Prophet
from prophet.serialize import model_from_json
from pydantic import BaseModel

app = FastAPI()

# Load the Prophet model
try:
    with open("serialized_model.json", "r") as fin:
        model = model_from_json(fin.read())
except FileNotFoundError:
    raise Exception("Prophet model file not found. Please ensure serialized_model.json is in the project directory.")


class PredictionInput(BaseModel):
    start_date: str
    end_date: str

@app.post("/predict")
async def predict(input_data: PredictionInput):
    # Validate start_date and end_date formats (YYYY-MM-DD)
    try:
        pd.to_datetime(input_data.start_date)
        pd.to_datetime(input_data.end_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Please use YYYY-MM-DD.")

    # Create a DataFrame for prediction based on input dates.
    future = pd.DataFrame({'ds': pd.date_range(input_data.start_date, input_data.end_date, freq='D')})
    
    forecast = model.predict(future)

    # Format and return results
    results = forecast[["ds", "yhat", "yhat_lower", "yhat_upper"]].to_dict('records')

    return {"forecast": results}

@app.get("/")
async def root():
    return {"message": "Hello World"}

@app.get("/items/{item_id}")
def read_item(item_id: int, q: Optional[str] = None):
    return {"item_id": item_id, "q": q}
