<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1" import="com.cs336.dbmstrainsproject.*"%>
<%@ page import="java.io.*,java.util.*,java.sql.*"%>
<%@ page session="true" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
    <title>Customer Representative Home</title>
</head>
<body>

<%
    //session check, redirect to login if not logged in or wrong role
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");

    if (username == null || !role.equals("rep")) {
        response.sendRedirect("login.jsp");
        return;
    }
%>

    <h2>Welcome, Customer Representative <%= username %>!</h2>
    <hr>

    <h3>Representative Dashboard:</h3>
    <table>
        <tr>
            <td><a href="repschedule.jsp">Manage Train Schedules</a></td>
        </tr>
        <tr>
            <td><a href="repforum.jsp">Customer Q&A / Replies</a></td>
        </tr>
    </table>

    <br>
    <a href="logout.jsp">Logout</a>

</body>
</html>