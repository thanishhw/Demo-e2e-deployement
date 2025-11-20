terraform {
  backend "s3" {
    bucket       = "tf-bucket"
    key          = "state-key"
    region       = "us-west-1"
    encrypt      = true
    dynamodb_table = "tf-locks"
  }
}
