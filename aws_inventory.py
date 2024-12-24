import argparse
import boto3
from datetime import datetime, timedelta
from botocore.exceptions import NoCredentialsError, PartialCredentialsError, ClientError


def parse_arguments():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="AWS Inventory Script")
    parser.add_argument("--debug", action="store_true", help="Enable debugging output.")
    return parser.parse_args()


def debug_print(message, debug_mode):
    """Print debug messages only if debug mode is enabled."""
    if debug_mode:
        print(f"DEBUG: {message}")


def get_all_regions(debug_mode):
    """Fetch all available AWS regions restricted to us-*."""
    try:
        ec2 = boto3.client("ec2")
        regions = ec2.describe_regions()["Regions"]
        region_names = [region["RegionName"] for region in regions if region["RegionName"].startswith("us-")]
        debug_print(f"Discovered us-* regions: {region_names}", debug_mode)
        return region_names
    except Exception as e:
        print(f"Error fetching regions: {e}")
        return []


def query_ec2_resources(debug_mode, regions):
    """Query EC2 resources including instances, volumes, and EIPs."""
    print("\n=== EC2 Resources ===\n")
    session = boto3.Session()

    for region in regions:
        try:
            client = session.client("ec2", region_name=region)

            # Instances
            response = client.describe_instances()
            instances_by_state = {}
            for reservation in response.get("Reservations", []):
                for instance in reservation.get("Instances", []):
                    state = instance["State"]["Name"]
                    instances_by_state[state] = instances_by_state.get(state, 0) + 1

            total_instances = sum(instances_by_state.values())
            print(f"EC2 Instances in {region}: {total_instances} (by state: {instances_by_state})")

            # Volumes
            response = client.describe_volumes()
            volume_count = len(response.get("Volumes", []))
            print(f"EBS Volumes in {region}: {volume_count}")

            # Elastic IPs
            response = client.describe_addresses()
            eip_count = len(response.get("Addresses", []))
            print(f"Elastic IPs in {region}: {eip_count}")

        except ClientError as ce:
            debug_print(f"ClientError querying EC2 in {region}: {ce}", debug_mode)
        except Exception as e:
            debug_print(f"Error querying EC2 in {region}: {e}", debug_mode)


def cost_driven_inventory(debug_mode):
    """Generate a report of billed services."""
    print("\n=== Cost-Driven Discovery Report ===\n")
    client = boto3.client("ce")
    end_date = datetime.utcnow().date()
    start_date = (end_date - timedelta(days=7)).strftime("%Y-%m-%d")
    end_date = end_date.strftime("%Y-%m-%d")

    try:
        response = client.get_cost_and_usage(
            TimePeriod={"Start": start_date, "End": end_date},
            Granularity="DAILY",
            Metrics=["BlendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )
        print("Billed Services (Last 7 Days):")
        for result in response.get("ResultsByTime", []):
            for group in result.get("Groups", []):
                service = group["Keys"][0]
                cost = float(group["Metrics"]["BlendedCost"]["Amount"])
                if cost > 0:
                    print(f"- {service}: ${cost:.2f}")
    except ClientError as ce:
        print(f"Error querying Cost Explorer API: {ce}")


def query_service_resources(service, operation, key, regions, debug_mode, global_service=False, extra_params=None):
    """Query resources dynamically for a given service and operation."""
    session = boto3.Session()
    total_count = 0

    regions_to_query = ["us-east-1"] if global_service else regions
    extra_params = extra_params or {}

    for region in regions_to_query:
        try:
            client = session.client(service, region_name=region)
            func = getattr(client, operation)
            response = func(**extra_params)
            resources = response.get(key, [])
            count = len(resources)
            if count > 0:
                print(f"{operation} ({service}) in {region}: {count}")
                total_count += count
        except ClientError as ce:
            debug_print(f"ClientError for {operation} ({service}) in {region}: {ce}", debug_mode)
        except Exception as e:
            debug_print(f"Error querying {operation} ({service}) in {region}: {e}", debug_mode)

    if total_count > 0:
        print(f"Total {operation} ({service}): {total_count}\n")


def service_discovery(debug_mode):
    """Perform service discovery for key AWS services."""
    print("\n=== Service Discovery Report ===\n")
    services_to_query = {
        "s3": [{"operation": "list_buckets", "key": "Buckets", "global": True}],
        "cloudformation": [{"operation": "describe_stacks", "key": "Stacks"}],
        "eks": [{"operation": "list_clusters", "key": "clusters"}],
        "dynamodb": [{"operation": "list_tables", "key": "TableNames"}],
        "elbv2": [{"operation": "describe_load_balancers", "key": "LoadBalancers"}],
        "elb": [{"operation": "describe_load_balancers", "key": "LoadBalancerDescriptions"}],
        "iam": [
            {"operation": "list_users", "key": "Users", "global": True},
            {"operation": "list_groups", "key": "Groups", "global": True},
            {"operation": "list_policies", "key": "Policies", "global": True, "extra_params": {"Scope": "Local"}},
            {"operation": "list_roles", "key": "Roles", "global": True},
        ],
    }

    regions = get_all_regions(debug_mode)
    query_ec2_resources(debug_mode, regions)

    for service, queries in services_to_query.items():
        for query in queries:
            query_service_resources(
                service,
                query["operation"],
                query["key"],
                regions,
                debug_mode,
                global_service=query.get("global", False),
                extra_params=query.get("extra_params"),
            )


def main():
    args = parse_arguments()
    debug_mode = args.debug

    try:
        cost_driven_inventory(debug_mode)
        service_discovery(debug_mode)
    except NoCredentialsError:
        print("No AWS credentials found. Please configure your credentials.")
    except PartialCredentialsError:
        print("Incomplete AWS credentials. Please check your configuration.")
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == "__main__":
    main()
