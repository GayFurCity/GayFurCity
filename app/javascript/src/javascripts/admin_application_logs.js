import Page from "./utility/page";

export default class ApplicationLogs {
  static init () {
    const status = $(".log-status");
    if (!status.length) return;

    const indicator = status.find(".new-log-lines-indicator");
    const url = status.data("status-url");
    let baselineCount = parseInt(status.data("current-count"), 10) || 0;

    const check = () => {
      $.ajax(url, {
        dataType: "json",
        data: { count: baselineCount },
      }).done((data) => {
        const newLines = parseInt(data.new_lines, 10) || 0;
        const totalCount = parseInt(data.total_count, 10) || baselineCount;

        if (totalCount < baselineCount) baselineCount = totalCount;

        if (newLines > 0) {
          const suffix = newLines === 1 ? "" : "s";
          indicator.text(`${newLines} new log line${suffix}`).show();
        } else {
          indicator.hide().text("");
        }
      });
    };

    check();
    setInterval(check, 15000);
  }
}

$(function () {
  if (Page.matches("admin-logs", "application-logs") || Page.matches("admin-logs", "request-logs")) ApplicationLogs.init();

  if (Page.matches("admin-logs", "performance-logs")) {
    $(document).on("click", ".log-query-sql", function () {
      const cell = $(this).toggleClass("expanded");
      cell.attr("title", cell.hasClass("expanded") ? "Click to collapse" : "Click to expand");
    });
  }
});
