# About

Stream stdin to a given S3 bucket.

This tool attempts to read the input as quickly as possible, using
memory buffers to hold any input that can not be written immediately
to S3.

The goal is to allow the sending program to write to stdout as fast as
possible. Currently it is much slower then `aws s3 cp` though. So this
is basically a proof of concept tool.


# Usage

```
    s3store --bucket www.example.com --key test1 < ~/tmp/image.jpg
```
