#!/bin/sh
aws ec2 describe-regions| grep RegionName | tr -d '"' | \
    awk '{print "module \"cloudbench-" $NF "\" {\nsource = \"cloudbench\"\nregion = \"" $NF "\"\n}"}' > main.tf
terraform fmt
