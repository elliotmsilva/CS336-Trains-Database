<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
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
    // ---- session check (admin only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"admin".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String message = null;

    // ---- handle add / update / delete (POST only) ----
    if ("POST".equalsIgnoreCase(request.getMethod())) {
        String action = request.getParameter("action");
        Connection mconn = null;
        PreparedStatement mps = null;
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            mconn = DriverManager.getConnection(
                "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

            if ("add".equals(action)) {
                String newUser = request.getParameter("emp_username");
                String newPass = request.getParameter("emp_password");
                String fname = request.getParameter("fname");
                String lname = request.getParameter("lname");
                String ssn = request.getParameter("ssn");

                if (newUser == null || newUser.trim().isEmpty()
                        || newPass == null || newPass.isEmpty()) {
                    message = "Username and password are required.";
                } else {
                    mps = mconn.prepareStatement(
                        "INSERT INTO Employee (username, password, first_name, last_name, ssn) " +
                        "VALUES (?, ?, ?, ?, ?)");
                    mps.setString(1, newUser.trim());
                    mps.setString(2, newPass);
                    mps.setString(3, fname);
                    mps.setString(4, lname);
                    mps.setString(5, ssn);
                    mps.executeUpdate();
                    message = "Representative added.";
                }

            } else if ("update".equals(action)) {
                String target = request.getParameter("emp_username");
                String newPass = request.getParameter("emp_password");
                String fname = request.getParameter("fname");
                String lname = request.getParameter("lname");
                String ssn = request.getParameter("ssn");

                if (newPass != null && !newPass.isEmpty()) {
                    mps = mconn.prepareStatement(
                        "UPDATE Employee SET password = ?, first_name = ?, " +
                        "last_name = ?, ssn = ? WHERE username = ?");
                    mps.setString(1, newPass);
                    mps.setString(2, fname);
                    mps.setString(3, lname);
                    mps.setString(4, ssn);
                    mps.setString(5, target);
                } else {
                    // blank password field = keep existing password
                    mps = mconn.prepareStatement(
                        "UPDATE Employee SET first_name = ?, last_name = ?, " +
                        "ssn = ? WHERE username = ?");
                    mps.setString(1, fname);
                    mps.setString(2, lname);
                    mps.setString(3, ssn);
                    mps.setString(4, target);
                }
                int rows = mps.executeUpdate();
                message = (rows > 0) ? "Representative updated."
                                     : "No such representative.";

            } else if ("delete".equals(action)) {
                String target = request.getParameter("emp_username");
                mps = mconn.prepareStatement(
                    "DELETE FROM Employee WHERE username = ?");
                mps.setString(1, target);
                int rows = mps.executeUpdate();
                message = (rows > 0) ? "Representative deleted."
                                     : "No such representative.";
            }
        } catch (SQLIntegrityConstraintViolationException dup) {
            message = "That username is already taken.";
        } catch (Exception e) {
            message = "Error: " + e.getMessage();
        } finally {
            if (mps != null) mps.close();
            if (mconn != null) mconn.close();
        }
    }

    // which rep (if any) is being edited
    String editing = request.getParameter("edit");
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Manage Customer Representatives</title>
</head>
<body>
    <h1>Manage Customer Representatives</h1>
    <p>
        <a href="adminhome.jsp">Home</a> |
        <a href="adminreservations.jsp">Reservations</a> |
        <a href="adminreports.jsp">Sales Reports</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= esc(message) %></b></p>
<%  } %>

    <h3>Add New Representative</h3>
    <form method="post" action="adminmanage.jsp">
        <input type="hidden" name="action" value="add">
        Username: <input type="text" name="emp_username" required>
        Password: <input type="password" name="emp_password" required>
        First name: <input type="text" name="fname">
        Last name: <input type="text" name="lname">
        SSN: <input type="text" name="ssn">
        <input type="submit" value="Add">
    </form>
    <hr>

    <h3>Current Representatives</h3>
    <table border="1" cellpadding="5">
        <tr>
            <th>Username</th><th>First Name</th><th>Last Name</th>
            <th>SSN</th><th colspan="2">Actions</th>
        </tr>
<%
    Connection conn = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        ps = conn.prepareStatement(
            "SELECT username, first_name, last_name, ssn " +
            "FROM Employee ORDER BY username");
        rs = ps.executeQuery();

        boolean any = false;
        while (rs.next()) {
            any = true;
            String empUser = rs.getString("username");

            if (empUser.equals(editing)) {
                // ---- inline edit row ----
%>
        <tr>
            <form method="post" action="adminmanage.jsp">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="emp_username" value="<%= esc(empUser) %>">
                <td><%= esc(empUser) %></td>
                <td><input type="text" name="fname"
                        value="<%= esc(rs.getString("first_name")) %>"></td>
                <td><input type="text" name="lname"
                        value="<%= esc(rs.getString("last_name")) %>"></td>
                <td><input type="text" name="ssn"
                        value="<%= esc(rs.getString("ssn")) %>"></td>
                <td>
                    New password (blank = keep):
                    <input type="password" name="emp_password"><br>
                    <input type="submit" value="Save">
                    <a href="adminmanage.jsp">Cancel</a>
                </td>
                <td></td>
            </form>
        </tr>
<%
            } else {
                // ---- normal row ----
%>
        <tr>
            <td><%= esc(empUser) %></td>
            <td><%= esc(rs.getString("first_name")) %></td>
            <td><%= esc(rs.getString("last_name")) %></td>
            <td><%= esc(rs.getString("ssn")) %></td>
            <td><a href="adminmanage.jsp?edit=<%= esc(empUser) %>">Edit</a></td>
            <td>
                <form method="post" action="adminmanage.jsp"
                      onsubmit="return window.confirm('Delete representative <%= esc(empUser) %>?');">
                    <input type="hidden" name="action" value="delete">
                    <input type="hidden" name="emp_username" value="<%= esc(empUser) %>">
                    <input type="submit" value="Delete">
                </form>
            </td>
        </tr>
<%
            }
        }
        if (!any) {
%>
        <tr><td colspan="6">No representatives yet.</td></tr>
<%
        }
    } catch (Exception e) {
%>
        <tr><td colspan="6">Error: <%= esc(e.getMessage()) %></td></tr>
<%
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (conn != null) conn.close();
    }
%>
    </table>
</body>
</html>
