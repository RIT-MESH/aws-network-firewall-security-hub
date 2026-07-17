locals {
  module_tags = merge(var.tags, {
    Module = "monitoring"
  })

  metric_namespace = "${var.name_prefix}/Firewall"

  has_alert_logs = var.alert_log_group_name != null
  has_flow_logs  = var.flow_log_group_name != null
}

# ----- SNS (optional) -----

resource "aws_sns_topic" "alarms" {
  count = var.enable_sns ? 1 : 0

  name = "${var.name_prefix}-firewall-alarms"
  tags = merge(local.module_tags, { Name = "${var.name_prefix}-firewall-alarms" })
}

# ----- Log metric filters -----

resource "aws_cloudwatch_log_metric_filter" "alert_count" {
  count = local.has_alert_logs ? 1 : 0

  name           = "${var.name_prefix}-firewall-alert-count"
  log_group_name = var.alert_log_group_name
  pattern        = "{ $.event_type = \"alert\" }"

  metric_transformation {
    name      = "FirewallAlertCount"
    namespace = local.metric_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "dropped_flow_count" {
  count = local.has_flow_logs ? 1 : 0

  name           = "${var.name_prefix}-firewall-dropped-flow-count"
  log_group_name = var.flow_log_group_name
  pattern        = "{ $.action = \"DROP\" }"

  metric_transformation {
    name      = "FirewallDroppedFlowCount"
    namespace = local.metric_namespace
    value     = "1"
  }
}

# ----- Alarms -----

resource "aws_cloudwatch_metric_alarm" "alert_volume" {
  count = local.has_alert_logs ? 1 : 0

  alarm_name          = "${var.name_prefix}-firewall-alert-volume-high"
  alarm_description   = "Firewall alert volume exceeded the configured threshold."
  namespace           = local.metric_namespace
  metric_name         = "FirewallAlertCount"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.alert_volume_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.enable_sns ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_sns ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(local.module_tags, { Name = "${var.name_prefix}-firewall-alert-volume-high" })
}

resource "aws_cloudwatch_metric_alarm" "dropped_spikes" {
  alarm_name        = "${var.name_prefix}-firewall-dropped-spikes"
  alarm_description = "Firewall dropped-packet volume exceeded the configured threshold."
  namespace         = "AWS/Network-Firewall"
  metric_name       = "DroppedPackets"
  dimensions = {
    Firewall = var.firewall_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.dropped_packet_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.enable_sns ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_sns ? [aws_sns_topic.alarms[0].arn] : []

  tags = merge(local.module_tags, { Name = "${var.name_prefix}-firewall-dropped-spikes" })
}

# ----- Dashboard -----

resource "aws_cloudwatch_dashboard" "firewall" {
  dashboard_name = "${var.name_prefix}-firewall"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Dropped packets"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Network-Firewall", "DroppedPackets", "Firewall", var.firewall_name],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Passed packets"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Network-Firewall", "PassedPackets", "Firewall", var.firewall_name],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Received packets"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/Network-Firewall", "ReceivedPacketCount", "Firewall", var.firewall_name],
          ]
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Firewall alerts (log metric)"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          metrics = [
            [local.metric_namespace, "FirewallAlertCount"],
            [local.metric_namespace, "FirewallDroppedFlowCount"],
          ]
          period = 300
        }
      },
    ]
  })
}