import requests
import pandas as pd
import datetime
import pyarrow
from airflow import DAG
from airflow.operators.python import PythonOperator
import os.path


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime.datetime(2025, 3, 15, 14,4,00),
    'retries': 1
}

url = 'https://api.openweathermap.org/data/2.5/weather?q=Minsk&appid=5310c780665b573cf2f6cf8cd8cc1d3c'

def api_wether(list,**context):
    current_time = datetime.datetime.now()
    current_date = current_time.date()

    res = requests.get(url)
    dt = res.json()
    for i in list:
        df_temp = pd.json_normalize(dt.get(i))
        df_temp['datetime'] = current_time
        file_path_temp = f'./output_files/minsk_{"{:%d_%m_%Y}".format(current_date)}_{i}.parquet'
        if os.path.exists(file_path_temp) is True:
            existing_ddf = pd.read_parquet(file_path_temp, engine='pyarrow')
            updated_ddf = pd.concat([existing_ddf, df_temp], axis=0)
            updated_ddf.to_parquet(file_path_temp, engine='pyarrow')
        else:
            df_temp.to_parquet(file_path_temp, engine='pyarrow')

    return 'ok'


with DAG(dag_id='api_wether_dag', catchup=False, default_args=default_args, schedule_interval=datetime.timedelta(minutes=60)):
    task1 = PythonOperator(task_id="api",
    python_callable=api_wether,
    provide_context=True,
    op_kwargs={"list":['main','wind']})


