terraform{
    backend "s3" {
        bucket         = "tf-bucket"
        key            = "state-key"
        region         = "us-west-1"
        dynamodb_table = "db_table"
        encrypt        = true
    }
}