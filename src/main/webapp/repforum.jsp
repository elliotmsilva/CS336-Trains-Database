<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="com.cs336.dbmstrainsproject.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
%>
<%
    // ---- session check (rep only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"rep".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String keyword = request.getParameter("keyword");
    if (keyword == null) keyword = "";
    boolean unansweredOnly = "1".equals(request.getParameter("unanswered"));

    String message = null;

    // ---- handle reply ----
    if ("POST".equalsIgnoreCase(request.getMethod())
            && request.getParameter("reply_submit") != null) {

        String body = request.getParameter("body");
        String qidStr = request.getParameter("question_id");

        if (body == null || body.trim().isEmpty()) {
            message = "Reply cannot be empty.";
        } else if (body.trim().length() > 500) {
            message = "Reply is too long (500 character max).";
        } else {
            ApplicationDB fdb = new ApplicationDB();
            Connection fconn = fdb.getConnection();
            PreparedStatement fps = null;
            ResultSet frs = null;
            try {
                int qid = Integer.parseInt(qidStr);

                // only reply to a real question, not another reply
                fps = fconn.prepareStatement(
                    "SELECT message_id FROM Forum " +
                    "WHERE message_id = ? AND reply_to IS NULL");
                fps.setInt(1, qid);
                frs = fps.executeQuery();
                if (!frs.next()) {
                    message = "No such question.";
                } else {
                    frs.close();
                    fps.close();
                    fps = fconn.prepareStatement(
                        "INSERT INTO Forum (message_date, body_text, username, reply_to) " +
                        "VALUES (NOW(), ?, ?, ?)");
                    fps.setString(1, body.trim());
                    fps.setString(2, username);
                    fps.setInt(3, qid);
                    fps.executeUpdate();
                    message = "Reply posted.";
                }
            } catch (NumberFormatException nfe) {
                message = "Invalid question.";
            } catch (Exception e) {
                message = "Error: " + e.getMessage();
            } finally {
                if (frs != null) frs.close();
                if (fps != null) fps.close();
                if (fconn != null) fdb.closeConnection(fconn);
            }
        }
    }

    String replyingTo = request.getParameter("reply_to");
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Customer Q&amp;A</title>
</head>
<body>
    <h1>Customer Questions</h1>
    <p>
        <a href="representativehome.jsp">Home</a> |
        <a href="repschedule.jsp">Manage Schedules</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= esc(message) %></b></p>
<%  } %>

    <form method="get" action="repforum.jsp">
        Search by keyword:
        <input type="text" name="keyword" value="<%= esc(keyword) %>">
        <label><input type="checkbox" name="unanswered" value="1"
            <%= unansweredOnly ? "checked" : "" %>> Unanswered only</label>
        <input type="submit" value="Search">
        <a href="repforum.jsp">Clear</a>
    </form>
    <br>
<%
    ApplicationDB db = new ApplicationDB();
    Connection conn = db.getConnection();
    PreparedStatement ps = null;
    PreparedStatement aps = null;
    ResultSet rs = null;
    try {
        String sql =
            "SELECT message_id, message_date, body_text, username " +
            "FROM Forum f WHERE reply_to IS NULL ";
        if (!keyword.isEmpty()) {
            sql += "AND body_text LIKE ? ";
        }
        if (unansweredOnly) {
            sql += "AND NOT EXISTS (SELECT 1 FROM Forum a " +
                   "WHERE a.reply_to = f.message_id) ";
        }
        sql += "ORDER BY message_date DESC";

        ps = conn.prepareStatement(sql);
        if (!keyword.isEmpty()) {
            ps.setString(1, "%" + keyword + "%");
        }
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
            int qid = rs.getInt("message_id");
%>
    <div style="border:1px solid black; padding:10px; margin-bottom:15px;">
        <b>Q:</b> <%= esc(rs.getString("body_text")) %><br>
        <i>asked by <%= esc(rs.getString("username")) %>
           on <%= rs.getTimestamp("message_date") %></i>
<%
            // answers to this question
            aps = conn.prepareStatement(
                "SELECT body_text, username, message_date FROM Forum " +
                "WHERE reply_to = ? ORDER BY message_date");
            aps.setInt(1, qid);
            ResultSet ars = aps.executeQuery();
            boolean answered = false;
            while (ars.next()) {
                answered = true;
%>
        <div style="margin-left:30px; border-left:2px solid gray;
                    padding-left:10px; margin-top:8px;">
            <b>A:</b> <%= esc(ars.getString("body_text")) %><br>
            <i>answered by <%= esc(ars.getString("username")) %>
               on <%= ars.getTimestamp("message_date") %></i>
        </div>
<%
            }
            if (!answered) {
%>
        <p><i>No answers yet.</i></p>
<%
            }
            ars.close();
            aps.close();

            if (String.valueOf(qid).equals(replyingTo)) {
%>
        <form method="post" action="repforum.jsp" style="margin-top:8px;">
            <input type="hidden" name="question_id" value="<%= qid %>">
            <textarea name="body" rows="3" cols="60" maxlength="500"></textarea><br>
            <input type="submit" name="reply_submit" value="Post Reply">
            <a href="repforum.jsp">Cancel</a>
        </form>
<%
            } else {
%>
        <p><a href="repforum.jsp?reply_to=<%= qid %>&keyword=<%=
            java.net.URLEncoder.encode(keyword, "UTF-8") %><%=
            unansweredOnly ? "&unanswered=1" : "" %>">Reply</a></p>
<%
            }
%>
    </div>
<%
        }
        if (!any) {
%>
    <p><%= unansweredOnly ? "No unanswered questions."
         : keyword.isEmpty() ? "No questions yet."
         : "No questions match your search." %></p>
<%
        }
    } catch (Exception e) {
%>
    <p>Error loading forum: <%= esc(e.getMessage()) %></p>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (aps != null) aps.close();
        if (conn != null) db.closeConnection(conn);
    }
%>
</body>
</html>
