from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, IntegerType, StringType

INPUT_PATH = "hdfs://team-36-nn:9000/user/hive/warehouse/hw3.db/events"
OUTPUT_PATH = "hdfs://team-36-nn:9000/user/team/hw4/events_summary"

spark = (
    SparkSession.builder
    .appName("HW4EventsSummary")
    .getOrCreate()
)

schema = StructType([
    StructField("user_id", IntegerType(), True),
    StructField("event", StringType(), True),
])

print("Reading partitioned source data from HDFS")

df = (
    spark.read
    .option("basePath", INPUT_PATH)
    .schema(schema)
    .csv(INPUT_PATH)
)

print("Source data")
df.show(truncate=False)

print("Applying transformations")

transformed = (
    df
    .withColumn("user_id", F.col("user_id").cast("long"))
    .withColumn("event", F.lower(F.trim(F.col("event"))))
    .withColumn("event_date", F.to_date(F.col("event_date")))
    .filter(
        F.col("user_id").isNotNull()
        & F.col("event").isNotNull()
        & F.col("event_date").isNotNull()
    )
)

summary = (
    transformed
    .groupBy("event_date", "event")
    .agg(
        F.count("*").alias("event_count"),
        F.countDistinct("user_id").alias("distinct_users"),
    )
)

print("Transformed data")
summary.show(truncate=False)

print("Writing partitioned Parquet to HDFS")

(
    summary
    .write
    .mode("overwrite")
    .partitionBy("event_date")
    .parquet(OUTPUT_PATH)
)

print(f"Output written to {OUTPUT_PATH}")

spark.stop()
