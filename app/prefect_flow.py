import subprocess
from pathlib import Path

from prefect import flow, task


ROOT = Path(__file__).resolve().parent.parent

HDFS_INPUT = "/user/hive/warehouse/hw3.db/events"
SPARK_APP = ROOT / "app" / "spark_events.py"
HIVE_SQL = ROOT / "sql" / "register-spark-table.sql"

HADOOP = "/opt/hadoop/bin"
SPARK_SUBMIT = "/opt/spark/bin/spark-submit"
BEELINE = "/opt/hive/bin/beeline"
JDBC_URL = "jdbc:hive2://team-36-00:10000/default"


def run(command: list[str]) -> None:
    print("$", " ".join(command))
    subprocess.run(command, check=True, cwd=ROOT)


@task
def check_hdfs() -> None:
    run([
        f"{HADOOP}/hdfs",
        "dfs",
        "-test",
        "-e",
        HDFS_INPUT,
    ])

    print("HDFS input is available")


@task
def run_spark() -> None:
    run([
        SPARK_SUBMIT,
        "--master", "yarn",
        "--deploy-mode", "client",
        "--conf", "spark.executor.instances=2",
        "--conf", "spark.executor.memory=512m",
        "--conf", "spark.executor.cores=1",
        str(SPARK_APP),
    ])


@task
def register_hive_table() -> None:
    run([
        BEELINE,
        "-u", JDBC_URL,
        "-f", str(HIVE_SQL),
    ])


@task
def verify_result() -> None:
    run([
        str(ROOT / "scripts" / "verify-spark.sh"),
    ])


@flow(name="hw5-spark-yarn-flow")
def hw5_flow() -> None:
    check_hdfs()
    run_spark()
    register_hive_table()
    verify_result()


if __name__ == "__main__":
    hw5_flow()
