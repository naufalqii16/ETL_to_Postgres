from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from datetime import datetime
import pandas as pd
from sqlalchemy import create_engine
import os

TMP_PATH = "/opt/airflow/tmp"

POSTGRES_CONN = "postgresql+psycopg2://airflow:airflow@postgres:5432/airflow"


# ---------- EXTRACT ----------
def extract_all():
    os.makedirs(TMP_PATH, exist_ok=True)
    pd.read_csv("/opt/airflow/data/mobility.csv") \
        .to_parquet(f"{TMP_PATH}/mobility.parquet", index=False)

    pd.read_csv("/opt/airflow/data/campaign_logs.csv") \
        .to_parquet(f"{TMP_PATH}/campaign.parquet", index=False)

    pd.read_csv("/opt/airflow/data/billboard.csv") \
        .to_parquet(f"{TMP_PATH}/billboard.parquet", index=False)


# ---------- CLEAN ----------
def clean_data(df):
    df = df.copy()

    if "device_id" in df.columns:
        df = df.dropna(subset=["device_id"])

        if "city" in df.columns:
            df["city"] = (
                df.groupby("device_id")["city"]
                  .transform(lambda x: x.fillna(x.mode().iloc[0]) if not x.mode().empty else x)
            )
            df = df.dropna(subset=["city"])

    if "daily_cost" in df.columns and "city" in df.columns:
        df["daily_cost"] = (
            df.groupby("city")["daily_cost"]
              .transform(lambda x: x.fillna(x.mean()))
        )
        df = df.dropna(subset=["daily_cost"])

    return df


def clean_all():
    campaign = pd.read_parquet(f"{TMP_PATH}/campaign.parquet")

    campaign = clean_data(campaign)

    campaign["exposure_time"] = pd.to_datetime(
        campaign["exposure_time"], errors="coerce"
    )
    campaign = campaign.dropna(subset=["exposure_time"])

    campaign.to_parquet(f"{TMP_PATH}/campaign_clean.parquet", index=False)


# ---------- TRANSFORM (MONTHLY REACH ONLY) ----------
def compute_monthly_reach():
    campaign = pd.read_parquet(f"{TMP_PATH}/campaign_clean.parquet")

    campaign["month"] = campaign["exposure_time"].dt.to_period("M").astype(str)

    result = (
        campaign
        .groupby(["billboard_id", "month"])["device_id"]
        .nunique()
        .reset_index(name="monthly_reach")
    )

    result.to_parquet(f"{TMP_PATH}/final_result.parquet", index=False)


# ---------- LOAD TO POSTGRES ----------
def load_to_postgres():
    df = pd.read_parquet(f"{TMP_PATH}/final_result.parquet")

    engine = create_engine(POSTGRES_CONN)

    df.to_sql(
        name="monthly_reach",
        con=engine,
        if_exists="replace",
        index=False
    )


# ---------- DAG ----------
with DAG(
    dag_id="load_monthly_reach_to_postgres",
    start_date=datetime(2026, 2, 1),
    schedule="@daily",
    catchup=False,
) as dag:

    extract = PythonOperator(
        task_id="extract_all",
        python_callable=extract_all
    )

    clean = PythonOperator(
        task_id="clean_all",
        python_callable=clean_all
    )

    transform = PythonOperator(
        task_id="compute_monthly_reach",
        python_callable=compute_monthly_reach
    )

    load = PythonOperator(
        task_id="load_to_postgres",
        python_callable=load_to_postgres
    )

    extract >> clean >> transform >> load
