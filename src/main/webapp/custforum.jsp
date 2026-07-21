<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    private String esc(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;");
    }
%>
<%
    // ---- session check (passenger only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"passenger".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String keyword = request.getParameter("keyword");
    if (keyword == null) keyword = "";

    String message = null;

    // ---- handle new question ----
    if ("POST".equalsIgnoreCase(request.getMethod())
            && request.getParameter("new_question") != null) {

        String body = request.getParameter("body");
        if (body != null && !body.trim().isEmpty()) {
            if (body.trim().length() > 500) {
                message = "Question is too long (500 character max).";
            } else {
                Connection fconn = null;
                PreparedStatement fps = null;
                try {
                    Class.forName("com.mysql.cj.jdbc.Driver");
                    fconn = DriverManager.getConnection(
                        "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

                    fps = fconn.prepareStatement(
                        "INSERT INTO Forum (message_date, body_text, username, reply_to) " +
                        "VALUES (NOW(), ?, ?, NULL)");
                    fps.setString(1, body.trim());
                    fps.setString(2, username);
                    fps.executeUpdate();
                    message = "Question posted!";
                } catch (Exception e) {
                    message = "Error: " + e.getMessage();
                } finally {
                    if (fps != null) fps.close();
                    if (fconn != null) fconn.close();
                }
            }
        } else {
            message = "Question cannot be empty.";
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Q&amp;A Forum</title>
</head>
<body>
    <h1>Q&amp;A Forum</h1>
    <p>
        <a href="customerhome.jsp">Home</a> |
        <a href="custschedule.jsp">Schedules</a> |
        <a href="custreservation.jsp">My Reservations</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= message %></b></p>
<%  } %>

    <h3>Ask a Question</h3>
    <form method="post" action="custforum.jsp">
        <textarea name="body" rows="4" cols="60" maxlength="500"></textarea><br>
        <input type="submit" name="new_question" value="Post Question">
    </form>
    <hr>

    <h3>Browse Questions</h3>
    <form method="get" action="custforum.jsp">
        Search by keyword:
        <input type="text" name="keyword" value="<%= esc(keyword) %>">
        <input type="submit" value="Search">
        <a href="custforum.jsp">Clear</a>
    </form>
    <br>
<%
    Connection conn = null;
    PreparedStatement ps = null;
    PreparedStatement aps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        String sql =
            "SELECT message_id, message_date, body_text, username " +
            "FROM Forum WHERE reply_to IS NULL ";
        if (!keyword.isEmpty()) {
            sql += "AND body_text LIKE ? ";
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
            // ---- answers to this question ----
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
%>
    </div>
<%
        }
        if (!any) {
%>
    <p><%= keyword.isEmpty() ? "No questions yet. Be the first to ask!"
                             : "No questions match your search." %></p>
<%
        }
    } catch (Exception e) {
%>
    <p>Error loading forum: <%= e.getMessage() %></p>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>
</body>
</html>
