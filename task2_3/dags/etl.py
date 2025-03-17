import datetime
from airflow import DAG
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.utils.trigger_rule import TriggerRule
from airflow.utils.task_group import TaskGroup

db_con = 'con_agg'
db_name = 'analytics_db'

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime.datetime(2025, 3, 15, 14,4,00),
    'retries': 1
}


# сюда можно дописать сколько угодно таблиц из сколько угодно бд, вся логика прописана на стороне базы agg  в файле task3.sql
load_table = [
    ('pages_project_c_db', 'pages'),
    ('pages_project_b_db', 'pages'),
    ('pages_project_a_db', 'pages'),
    ('events_project_a_db', 'events'),
    ('events_project_b_db', 'events'),
    ('events_project_c_db', 'events'),
    ('user_sessions_project_c_db', 'user_sessions'),
    ('user_sessions_project_b_db', 'user_sessions'),
    ('user_sessions_project_a_db', 'user_sessions')
]

with DAG(dag_id='etl_dag', catchup=False, default_args=default_args, schedule_interval=datetime.timedelta(minutes=10)):

    with TaskGroup(group_id='load_tables') as load_tables_gr:
        det_tsk = {}
        for source_table, work_table in load_table:
            det_tsk[source_table] = PostgresOperator(
                task_id=source_table,
                sql=f'select load_tables(\'{source_table}\', \'{work_table}\');',
                postgres_conn_id=db_con,
                database=db_name
            )

    load_analytics_sessions = PostgresOperator(
        task_id='load_analytics_sessions',
        postgres_conn_id=db_con,
        sql=f'select load_analytics_sessions();',
        database=db_name,
        trigger_rule=TriggerRule.ALL_SUCCESS)

    load_tables_gr >> load_analytics_sessions