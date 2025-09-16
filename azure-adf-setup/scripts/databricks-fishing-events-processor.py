# Databricks notebook source
# MAGIC %md
# MAGIC # Global Fishing Watch Events Data Processing
# MAGIC 
# MAGIC This notebook processes raw fishing events data from Global Fishing Watch API v3
# MAGIC and prepares it for port visit analysis and investment insights.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup and Configuration

# COMMAND ----------

import json
import pandas as pd
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime, timedelta
import requests

# Initialize Spark session
spark = SparkSession.builder.appName("FishingEventsProcessor").getOrCreate()

# Get parameters from ADF pipeline
storage_account = dbutils.widgets.get("storage_account")
input_container = dbutils.widgets.get("input_container")
output_container = dbutils.widgets.get("output_container")
processing_date = dbutils.widgets.get("processing_date")

print(f"Processing fishing events data for date: {processing_date}")
print(f"Storage account: {storage_account}")
print(f"Input container: {input_container}")
print(f"Output container: {output_container}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Loading and Schema Definition

# COMMAND ----------

# Define schema for fishing events
fishing_events_schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("event_type", StringType(), True),
    StructField("vessel", StructType([
        StructField("id", StringType(), True),
        StructField("ssvid", StringType(), True),
        StructField("name", StringType(), True),
        StructField("flag", StringType(), True),
        StructField("vessel_class", StringType(), True)
    ]), True),
    StructField("port", StructType([
        StructField("id", StringType(), True),
        StructField("name", StringType(), True),
        StructField("country", StringType(), True),
        StructField("coordinates", ArrayType(DoubleType()), True)
    ]), True),
    StructField("start", StringType(), True),
    StructField("end", StringType(), True),
    StructField("duration_hours", DoubleType(), True)
])

# Load raw fishing events data
input_path = f"abfss://{input_container}@{storage_account}.dfs.core.windows.net/fishing-events/"
print(f"Loading data from: {input_path}")

try:
    # Find the latest JSON file
    files = dbutils.fs.ls(input_path)
    json_files = [f for f in files if f.name.endswith('.json')]
    
    if not json_files:
        raise Exception("No JSON files found in input path")
    
    # Sort by modification time and get the latest
    latest_file = sorted(json_files, key=lambda x: x.modificationTime, reverse=True)[0]
    latest_file_path = latest_file.path
    
    print(f"Processing file: {latest_file.name}")
    
    # Read the JSON file
    raw_df = spark.read.option("multiline", "true").json(latest_file_path)
    
    print(f"Raw data loaded successfully. Record count: {raw_df.count()}")
    raw_df.printSchema()
    
except Exception as e:
    print(f"Error loading data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Processing and Transformation

# COMMAND ----------

# Extract events from the nested structure
def process_fishing_events(df):
    """
    Process raw fishing events data and flatten the structure
    """
    try:
        # Check if data has 'events' array or is already flattened
        if 'events' in df.columns:
            # Explode the events array
            events_df = df.select(explode(col("events")).alias("event"))
            
            # Flatten the structure
            processed_df = events_df.select(
                col("event.event_id").alias("event_id"),
                col("event.event_type").alias("event_type"),
                col("event.vessel.id").alias("vessel_id"),
                col("event.vessel.ssvid").alias("vessel_ssvid"),
                col("event.vessel.name").alias("vessel_name"),
                col("event.vessel.flag").alias("vessel_flag"),
                col("event.vessel.vessel_class").alias("vessel_class"),
                col("event.port.id").alias("port_id"),
                col("event.port.name").alias("port_name"),
                col("event.port.country").alias("port_country"),
                col("event.port.coordinates").alias("port_coordinates"),
                col("event.start").alias("start_time"),
                col("event.end").alias("end_time"),
                col("event.duration_hours").alias("duration_hours")
            )
        else:
            # Data is already flattened
            processed_df = df
            
        # Extract coordinates
        processed_df = processed_df.withColumn(
            "port_longitude", 
            when(col("port_coordinates").isNotNull() & (size(col("port_coordinates")) >= 2), 
                 col("port_coordinates")[0]).otherwise(None)
        ).withColumn(
            "port_latitude", 
            when(col("port_coordinates").isNotNull() & (size(col("port_coordinates")) >= 2), 
                 col("port_coordinates")[1]).otherwise(None)
        ).drop("port_coordinates")
        
        # Convert timestamp strings to datetime
        processed_df = processed_df.withColumn(
            "start_time", 
            to_timestamp(col("start_time"), "yyyy-MM-dd'T'HH:mm:ss'Z'")
        ).withColumn(
            "end_time", 
            to_timestamp(col("end_time"), "yyyy-MM-dd'T'HH:mm:ss'Z'")
        )
        
        # Calculate duration if not provided
        processed_df = processed_df.withColumn(
            "duration_hours",
            when(col("duration_hours").isNull() & col("end_time").isNotNull() & col("start_time").isNotNull(),
                 (unix_timestamp(col("end_time")) - unix_timestamp(col("start_time"))) / 3600
            ).otherwise(col("duration_hours"))
        )
        
        # Add processing date
        processed_df = processed_df.withColumn(
            "processing_date", 
            lit(processing_date).cast("timestamp")
        )
        
        # Filter for port visits (primary focus for investment analysis)
        port_visits_df = processed_df.filter(col("event_type") == "port_visit")
        
        print(f"Total events processed: {processed_df.count()}")
        print(f"Port visit events: {port_visits_df.count()}")
        
        return processed_df, port_visits_df
        
    except Exception as e:
        print(f"Error processing events: {str(e)}")
        raise

# Process the data
processed_events_df, port_visits_df = process_fishing_events(raw_df)

# Show sample data
print("Sample processed events:")
processed_events_df.show(5, truncate=False)

print("\nSample port visits:")
port_visits_df.show(5, truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality and Validation

# COMMAND ----------

def validate_data_quality(df, df_name):
    """
    Perform data quality checks on the processed data
    """
    print(f"\n=== Data Quality Report for {df_name} ===")
    
    total_records = df.count()
    print(f"Total records: {total_records}")
    
    if total_records == 0:
        print("WARNING: No records found!")
        return
    
    # Check for null values in critical fields
    critical_fields = ["event_id", "event_type", "vessel_id", "start_time"]
    
    for field in critical_fields:
        if field in df.columns:
            null_count = df.filter(col(field).isNull()).count()
            null_percentage = (null_count / total_records) * 100
            print(f"{field}: {null_count} nulls ({null_percentage:.2f}%)")
    
    # Port-specific validation for port visits
    if "port_id" in df.columns:
        port_null_count = df.filter(col("port_id").isNull()).count()
        port_null_percentage = (port_null_count / total_records) * 100
        print(f"port_id: {port_null_count} nulls ({port_null_percentage:.2f}%)")
        
        valid_ports = df.filter(col("port_id").isNotNull()).count()
        print(f"Records with valid port data: {valid_ports}")
    
    # Duration validation
    if "duration_hours" in df.columns:
        invalid_duration = df.filter(
            (col("duration_hours").isNull()) | 
            (col("duration_hours") <= 0) | 
            (col("duration_hours") > 8760)  # More than a year
        ).count()
        print(f"Invalid duration records: {invalid_duration}")
    
    # Unique values
    unique_events = df.select("event_id").distinct().count()
    unique_vessels = df.select("vessel_id").distinct().count()
    
    print(f"Unique events: {unique_events}")
    print(f"Unique vessels: {unique_vessels}")
    
    if "port_id" in df.columns:
        unique_ports = df.filter(col("port_id").isNotNull()).select("port_id").distinct().count()
        print(f"Unique ports: {unique_ports}")

# Validate data quality
validate_data_quality(processed_events_df, "All Events")
validate_data_quality(port_visits_df, "Port Visits")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Port Visit Analysis Preparation

# COMMAND ----------

def prepare_port_analysis_data(port_visits_df):
    """
    Prepare data specifically for port visit analysis
    """
    # Filter for valid port visits with required data
    valid_port_visits = port_visits_df.filter(
        col("port_id").isNotNull() &
        col("port_name").isNotNull() &
        col("vessel_id").isNotNull() &
        col("start_time").isNotNull() &
        col("duration_hours").isNotNull() &
        (col("duration_hours") > 0) &
        (col("duration_hours") <= 8760)  # Reasonable duration limit
    )
    
    # Calculate additional metrics
    enhanced_port_visits = valid_port_visits.withColumn(
        "visit_date", date_format(col("start_time"), "yyyy-MM-dd")
    ).withColumn(
        "visit_month", date_format(col("start_time"), "yyyy-MM")
    ).withColumn(
        "visit_year", year(col("start_time"))
    ).withColumn(
        "duration_days", col("duration_hours") / 24
    )
    
    print(f"Valid port visits for analysis: {enhanced_port_visits.count()}")
    
    return enhanced_port_visits

# Prepare port analysis data
port_analysis_df = prepare_port_analysis_data(port_visits_df)

# Show summary statistics
print("\nPort Visit Summary Statistics:")
port_analysis_df.groupBy("port_country").agg(
    count("*").alias("total_visits"),
    countDistinct("port_id").alias("unique_ports"),
    countDistinct("vessel_id").alias("unique_vessels"),
    avg("duration_hours").alias("avg_duration_hours"),
    sum("duration_hours").alias("total_duration_hours")
).orderBy(desc("total_visits")).show(20)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Save Processed Data

# COMMAND ----------

def save_processed_data(df, output_path, file_name):
    """
    Save processed data to Azure Data Lake
    """
    try:
        full_output_path = f"{output_path}/{file_name}"
        print(f"Saving data to: {full_output_path}")
        
        # Save as single CSV file (coalesce to 1 partition)
        df.coalesce(1).write.mode("overwrite").option("header", "true").csv(full_output_path)
        
        # Get the actual file name (Spark creates a part file)
        files = dbutils.fs.ls(full_output_path)
        csv_file = [f for f in files if f.name.startswith("part-") and f.name.endswith(".csv")][0]
        
        # Rename to desired filename
        desired_path = f"{output_path}/{file_name}.csv"
        dbutils.fs.cp(csv_file.path, desired_path)
        dbutils.fs.rm(full_output_path, recurse=True)
        
        print(f"Data saved successfully to: {desired_path}")
        
    except Exception as e:
        print(f"Error saving data: {str(e)}")
        raise

# Define output paths
output_path = f"abfss://{output_container}@{storage_account}.dfs.core.windows.net/fishing-events"

# Save all processed events
save_processed_data(processed_events_df, output_path, "processed_fishing_events")

# Save port visits specifically for analysis
save_processed_data(port_analysis_df, output_path, "port_visit_analysis")

# Create summary statistics for quick insights
port_summary = port_analysis_df.groupBy(
    "port_id", "port_name", "port_country", "port_latitude", "port_longitude"
).agg(
    count("*").alias("visit_count"),
    countDistinct("vessel_id").alias("unique_vessels"),
    avg("duration_hours").alias("avg_stay_hours"),
    sum("duration_hours").alias("total_trade_hours"),
    min("start_time").alias("first_visit"),
    max("start_time").alias("last_visit")
).withColumn("processing_date", lit(processing_date).cast("timestamp"))

save_processed_data(port_summary, output_path, "port_summary_stats")

print(f"\nProcessing completed successfully!")
print(f"Files saved:")
print(f"1. processed_fishing_events.csv - All processed events")
print(f"2. port_visit_analysis.csv - Port visits for detailed analysis")
print(f"3. port_summary_stats.csv - Port summary statistics")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Generate Processing Report

# COMMAND ----------

# Create processing report
processing_report = {
    "processing_date": processing_date,
    "processing_timestamp": datetime.now().isoformat(),
    "total_events_processed": processed_events_df.count(),
    "port_visits_processed": port_analysis_df.count(),
    "unique_vessels": processed_events_df.select("vessel_id").distinct().count(),
    "unique_ports": port_analysis_df.filter(col("port_id").isNotNull()).select("port_id").distinct().count(),
    "unique_countries": port_analysis_df.filter(col("port_country").isNotNull()).select("port_country").distinct().count(),
    "date_range": {
        "earliest_event": processed_events_df.agg(min("start_time")).collect()[0][0],
        "latest_event": processed_events_df.agg(max("start_time")).collect()[0][0]
    },
    "data_quality": {
        "valid_port_visits_percentage": (port_analysis_df.count() / processed_events_df.filter(col("event_type") == "port_visit").count()) * 100 if processed_events_df.filter(col("event_type") == "port_visit").count() > 0 else 0
    }
}

# Convert to DataFrame and save
report_df = spark.createDataFrame([processing_report])
save_processed_data(report_df, output_path, "processing_report")

print("\n=== Processing Report ===")
for key, value in processing_report.items():
    print(f"{key}: {value}")

print("\nData processing pipeline completed successfully! 🎉")
