import psycopg2
import time
from concurrent.futures import ThreadPoolExecutor
import logging
from dataclasses import dataclass
from typing import List, Tuple
import threading
from decimal import Decimal

@dataclass
class TemperatureCorrection:
    temperature: float
    correction: float

def db_connect() -> psycopg2.extensions.connection:
    try:
        conn = psycopg2.connect(
            dbname="testdb",
            user="testuser",
            password="testpass",
            host="localhost",
            port="5433"
        )
        return conn
    except Exception as e:
        logging.error(f"Failed to connect to database: {e}")
        raise

def linear_interpolation(target_temp: float, data: List[TemperatureCorrection]) -> Tuple[float, None]:
    if target_temp < data[0].temperature or target_temp > data[-1].temperature:
        print(f"Target temperature: {target_temp}, Min: {data[0].temperature}, Max: {data[-1].temperature}")
        raise ValueError(f"Target temperature out of range: {target_temp}")

    for i in range(len(data) - 1):
        if data[i].temperature <= target_temp <= data[i + 1].temperature:
            x0, y0 = data[i].temperature, data[i].correction
            x1, y1 = data[i + 1].temperature, data[i + 1].correction
            return y0 + (y1 - y0) * (target_temp - x0) / (x1 - x0), None

    raise ValueError(f"Target temperature not found in range: {target_temp}")

def process_temperature(target_temp: float, conn: psycopg2.extensions.connection, lock: threading.Lock, counter: list) -> None:
    try:
        with conn.cursor() as cur:
            query = "SELECT temperature, correction FROM calc_temperatures_correction ORDER BY temperature ASC;"
            with lock:
                cur.execute(query)
                rows = cur.fetchall()
                local_data = [
                    TemperatureCorrection(
                        temperature=float(row[0]) if isinstance(row[0], Decimal) else row[0],
                        correction=float(row[1]) if isinstance(row[1], Decimal) else row[1]
                    ) 
                    for row in rows
                ]
            
            linear_interpolation(target_temp, local_data)
            with lock:
                counter[0] += 1
    except Exception as e:
        logging.error(f"Error processing temperature {target_temp}: {e}")

def main():
    logging.basicConfig(level=logging.INFO)
    conn = db_connect()
    lock = threading.Lock()
    counter = [0]
    
    start_time = time.time()
    
    temperatures = [i/100 for i in range(0, 4001)]
    
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [
            executor.submit(process_temperature, temp, conn, lock, counter)
            for temp in temperatures
        ]
        
        for future in futures:
            future.result()
    
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"Duration: {duration} seconds, Count: {counter[0]}")
    
    conn.close()

if __name__ == "__main__":
    main()
