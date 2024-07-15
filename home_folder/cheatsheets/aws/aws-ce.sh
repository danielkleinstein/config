aws ce get-cost-and-usage-with-resources \
    --time-period Start=2024-02-01,End=2024-02-05 \
    --granularity MONTHLY \
    --metrics "UnblendedCost" \
    --filter '
    {
        "And":
        [
            {
                "Dimensions":
                {
                    "Key": "SERVICE",
                    "Values": ["Amazon Elastic Compute Cloud - Compute"]
                }
            },
            {
                "Dimensions": {
                    "Key": "RESOURCE_ID",
                    "Values": ["i-016183c6a151faab5"]
                }
            }
        ]
    }' \
    --group-by '[{"Type": "DIMENSION", "Key": "RESOURCE_ID"}]'

