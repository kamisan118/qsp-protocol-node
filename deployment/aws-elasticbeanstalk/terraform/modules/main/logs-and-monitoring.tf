resource "aws_cloudwatch_log_group" "main" {
  name = "qsp-protocol-nodes-${var.stage}"

  tags {
    Environment = "${var.stage}"
  }
}

resource "aws_sns_topic" "node_errors" {
  name = "${var.environment}-errors"
}

resource "aws_cloudwatch_log_metric_filter" "node_errors_filter" {
  name = "${var.environment}-errors-log-filter"
  pattern = "{$.level = \"error\"}"
  log_group_name = "${aws_cloudwatch_log_group.main.name}"
  metric_transformation {
    name = "${var.environment}-errors"
    namespace = "LogMetrics"
    value = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "node_errors" {
  alarm_name                = "${var.environment}-errors"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "${var.environment}-errors"
  namespace                 = "LogMetrics"
  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "1"
  alarm_description         = "This alarm goes off whenever an error appears in the logs"
  alarm_actions             = ["${aws_sns_topic.node_errors.arn}"]
}