<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    // escape <, >, & so posted text can't inject HTML/scripts
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

    String message = null;

    // ---- handle new message ----
    if ("POST".equalsIgnoreCase(request.getMethod())
            && request.getParameter("new_message") != null) {

        String body = request.getParameter("body");
        if (body != null && !body.trim().isEmpty()) {
            if (body.trim().length() > 500) {
                message = "Message is too long (500 character max).";
            } else {
                Connection fconn = null;
                PreparedStatement fps = null;
                try {
                    Class.forName("com.mysql.cj.jdbc.Driver");
                    fconn = DriverManager.getConnection(
                        "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

                    fps = fconn.prepareStatement(
                        "INSERT INTO Forum (message_date, body_text) " +
                        "VALUES (NOW(), ?)");
                    fps.setString(1, body.trim());
                    fps.executeUpdate();
                    message = "Message posted!";
                } catch (Exception e) {
                    message = "Error: " + e.getMessage();
                } finally {
                    if (fps != null) fps.close();
                    if (fconn != null) fconn.close();
                }
            }
        } else {
            message = "Message cannot be empty.";
        }
    }
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Customer Forum</title>
</head>
<body>
    <h1>Customer Forum</h1>
    <p>
        <a href="customerhome.jsp">Home</a> |
        <a href="custschedule.jsp">Schedules</a> |
        <a href="custreservation.jsp">My Reservations</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= message %></b></p>
<%  } %>

    <h3>Post a Message</h3>
    <form method="post" action="custforum.jsp">
        <textarea name="body" rows="4" cols="60" maxlength="500"></textarea><br>
        <input type="submit" name="new_message" value="Post">
    </form>
    <hr>

    <h3>Messages</h3>
<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        ps = conn.prepareStatement(
            "SELECT message_id, message_date, body_text " +
            "FROM Forum ORDER BY message_date DESC");
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
%>
    <div style="border:1px solid black; padding:10px; margin-bottom:10px;">
        <i><%= rs.getTimestamp("message_date") %></i>
        <p><%= esc(rs.getString("body_text")) %></p>
    </div>
<%
        }
        if (!any) {
%>
    <p>No messages yet. Be the first to post!</p>
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
