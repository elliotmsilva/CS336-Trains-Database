<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%!
    // "2026-07-21T10:30" (datetime-local input) -> "2026-07-21 10:30:00"
    private String toSqlDatetime(String s) {
        if (s == null || s.trim().isEmpty()) return null;
        return s.trim().replace('T', ' ') + ":00";
    }
%>
<%
    // ---- session check (manager only) ----
    String username = (String) session.getAttribute("username");
    String role = (String) session.getAttribute("role");
    if (username == null || !"manager".equals(role)) {
        response.sendRedirect("login.jsp");
        return;
    }

    String message = null;
    Connection conn = null;
    PreparedStatement ps = null;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        conn = DriverManager.getConnection(
            "jdbc:mysql://localhost:3306/cs336project", "root", "yourpassword");

        // ================= POST handlers =================
        if ("POST".equalsIgnoreCase(request.getMethod())) {

            if (request.getParameter("add_line") != null) {
                String name = request.getParameter("line_name");
                String fare = request.getParameter("fare");
                String stationId = request.getParameter("station_id");
                if (name != null && !name.trim().isEmpty()
                        && fare != null && !fare.trim().isEmpty()) {
                    ps = conn.prepareStatement(
                        "INSERT INTO TransitLine (name, fare, station_id) " +
                        "VALUES (?, ?, ?)");
                    ps.setString(1, name.trim());
                    ps.setInt(2, Integer.parseInt(fare.trim()));
                    if (stationId == null || stationId.isEmpty()) {
                        ps.setNull(3, Types.INTEGER);
                    } else {
                        ps.setInt(3, Integer.parseInt(stationId));
                    }
                    ps.executeUpdate();
                    ps.close();
                    message = "Transit line added.";
                } else {
                    message = "Line name and fare are required.";
                }

            } else if (request.getParameter("update_fare") != null) {
                ps = conn.prepareStatement(
                    "UPDATE TransitLine SET fare = ? WHERE line_id = ?");
                ps.setInt(1, Integer.parseInt(request.getParameter("fare")));
                ps.setInt(2, Integer.parseInt(request.getParameter("line_id")));
                ps.executeUpdate();
                ps.close();
                message = "Fare updated.";

            } else if (request.getParameter("add_station") != null) {
                String sname = request.getParameter("station_name");
                String city = request.getParameter("city");
                String state = request.getParameter("state");
                if (sname != null && !sname.trim().isEmpty()
                        && city != null && !city.trim().isEmpty()
                        && state != null && !state.trim().isEmpty()) {
                    ps = conn.prepareStatement(
                        "INSERT INTO Station (station_name, city, state) " +
                        "VALUES (?, ?, ?)");
                    ps.setString(1, sname.trim());
                    ps.setString(2, city.trim());
                    ps.setString(3, state.trim());
                    ps.executeUpdate();
                    ps.close();
                    message = "Station added.";
                } else {
                    message = "Station name, city, and state are all required.";
                }

            } else if (request.getParameter("add_train") != null) {
                String tid = request.getParameter("train_id");
                try {
                    int id = Integer.parseInt(tid.trim());
                    if (id < 1000 || id > 9999) {
                        message = "Train ID must be between 1000 and 9999.";
                    } else {
                        ps = conn.prepareStatement(
                            "INSERT INTO Train (train_id) VALUES (?)");
                        ps.setInt(1, id);
                        ps.executeUpdate();
                        ps.close();
                        message = "Train " + id + " added.";
                    }
                } catch (NumberFormatException nfe) {
                    message = "Train ID must be a number.";
                } catch (SQLException dup) {
                    message = "That train ID already exists.";
                }

            } else if (request.getParameter("add_stop") != null) {
                ps = conn.prepareStatement(
                    "INSERT INTO TrainStop " +
                    "(line_id, station_id, arrival_datetime, departure_datetime) " +
                    "VALUES (?, ?, ?, ?)");
                ps.setInt(1, Integer.parseInt(request.getParameter("line_id")));
                ps.setInt(2, Integer.parseInt(request.getParameter("station_id")));
                ps.setString(3, toSqlDatetime(request.getParameter("arrival")));
                ps.setString(4, toSqlDatetime(request.getParameter("departure")));
                ps.executeUpdate();
                ps.close();
                message = "Train stop added.";

            } else if (request.getParameter("add_schedule") != null) {
                ps = conn.prepareStatement(
                    "INSERT INTO Schedule " +
                    "(stops, arrival_time, departure_time, line_id, train_id, stop_id) " +
                    "VALUES (?, ?, ?, ?, ?, ?)");
                ps.setString(1, request.getParameter("stops"));
                ps.setString(2, toSqlDatetime(request.getParameter("arrival")));
                ps.setString(3, toSqlDatetime(request.getParameter("departure")));
                ps.setInt(4, Integer.parseInt(request.getParameter("line_id")));
                ps.setInt(5, Integer.parseInt(request.getParameter("train_id")));
                ps.setInt(6, Integer.parseInt(request.getParameter("stop_id")));
                ps.executeUpdate();
                ps.close();
                message = "Schedule added.";
            }
        }

        // ================= delete handlers (GET links) =================
        try {
            String del;
            if ((del = request.getParameter("delete_line")) != null) {
                ps = conn.prepareStatement("DELETE FROM TransitLine WHERE line_id = ?");
                ps.setInt(1, Integer.parseInt(del));
                ps.executeUpdate(); ps.close();
                message = "Transit line deleted.";
            } else if ((del = request.getParameter("delete_station")) != null) {
                ps = conn.prepareStatement("DELETE FROM Station WHERE station_id = ?");
                ps.setInt(1, Integer.parseInt(del));
                ps.executeUpdate(); ps.close();
                message = "Station deleted.";
            } else if ((del = request.getParameter("delete_train")) != null) {
                ps = conn.prepareStatement("DELETE FROM Train WHERE train_id = ?");
                ps.setInt(1, Integer.parseInt(del));
                ps.executeUpdate(); ps.close();
                message = "Train deleted.";
            } else if ((del = request.getParameter("delete_stop")) != null) {
                ps = conn.prepareStatement("DELETE FROM TrainStop WHERE stop_id = ?");
                ps.setInt(1, Integer.parseInt(del));
                ps.executeUpdate(); ps.close();
                message = "Train stop deleted.";
            } else if ((del = request.getParameter("delete_schedule")) != null) {
                ps = conn.prepareStatement("DELETE FROM Schedule WHERE schedule_id = ?");
                ps.setInt(1, Integer.parseInt(del));
                ps.executeUpdate(); ps.close();
                message = "Schedule deleted.";
            }
        } catch (SQLException delEx) {
            message = "Cannot delete: it is still referenced by another record "
                    + "(schedule, stop, or reservation). Remove those first.";
        }
%>
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Manage System</title>
</head>
<body>
    <h1>Manage System</h1>
    <p>
        <a href="adminhome.jsp">Home</a> |
        <a href="adminreservations.jsp">Reservations</a> |
        <a href="adminreports.jsp">Reports</a> |
        <a href="logout.jsp">Logout</a>
    </p>

<%  if (message != null) { %>
    <p><b><%= message %></b></p>
<%  } %>

    <!-- ================= Stations ================= -->
    <h3>Stations</h3>
    <form method="post" action="adminmanage.jsp">
        Name: <input type="text" name="station_name">
        City: <input type="text" name="city">
        State: <input type="text" name="state" size="10">
        <input type="submit" name="add_station" value="Add Station">
    </form>
    <table border="1" cellpadding="5">
        <tr><th>ID</th><th>Name</th><th>City</th><th>State</th><th></th></tr>
<%
        Statement st = conn.createStatement();
        ResultSet rs = st.executeQuery(
            "SELECT station_id, station_name, city, state FROM Station ORDER BY station_id");
        while (rs.next()) {
%>
        <tr>
            <td><%= rs.getInt("station_id") %></td>
            <td><%= rs.getString("station_name") %></td>
            <td><%= rs.getString("city") %></td>
            <td><%= rs.getString("state") %></td>
            <td><a href="adminmanage.jsp?delete_station=<%= rs.getInt("station_id") %>">Delete</a></td>
        </tr>
<%      }
        rs.close(); %>
    </table>

    <!-- ================= Transit Lines ================= -->
    <h3>Transit Lines</h3>
    <form method="post" action="adminmanage.jsp">
        Name: <input type="text" name="line_name" maxlength="20">
        Fare: <input type="text" name="fare" size="5">
        Station:
        <select name="station_id">
            <option value="">(none)</option>
<%
        rs = st.executeQuery("SELECT station_id, station_name FROM Station ORDER BY station_name");
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("station_id") %>"><%= rs.getString("station_name") %></option>
<%      }
        rs.close(); %>
        </select>
        <input type="submit" name="add_line" value="Add Line">
    </form>
    <table border="1" cellpadding="5">
        <tr><th>ID</th><th>Name</th><th>Fare</th><th>Station</th><th></th></tr>
<%
        rs = st.executeQuery(
            "SELECT tl.line_id, tl.name, tl.fare, s.station_name " +
            "FROM TransitLine tl LEFT JOIN Station s ON tl.station_id = s.station_id " +
            "ORDER BY tl.line_id");
        while (rs.next()) {
            int lineId = rs.getInt("line_id");
            String stName = rs.getString("station_name");
%>
        <tr>
            <td><%= lineId %></td>
            <td><%= rs.getString("name") %></td>
            <td>
                <form method="post" action="adminmanage.jsp" style="margin:0;">
                    <input type="hidden" name="line_id" value="<%= lineId %>">
                    <input type="text" name="fare" size="5" value="<%= rs.getInt("fare") %>">
                    <input type="submit" name="update_fare" value="Update">
                </form>
            </td>
            <td><%= stName != null ? stName : "-" %></td>
            <td><a href="adminmanage.jsp?delete_line=<%= lineId %>">Delete</a></td>
        </tr>
<%      }
        rs.close(); %>
    </table>

    <!-- ================= Trains ================= -->
    <h3>Trains</h3>
    <form method="post" action="adminmanage.jsp">
        Train ID (1000-9999): <input type="text" name="train_id" size="6">
        <input type="submit" name="add_train" value="Add Train">
    </form>
    <table border="1" cellpadding="5">
        <tr><th>Train ID</th><th></th></tr>
<%
        rs = st.executeQuery("SELECT train_id FROM Train ORDER BY train_id");
        while (rs.next()) {
%>
        <tr>
            <td><%= rs.getInt("train_id") %></td>
            <td><a href="adminmanage.jsp?delete_train=<%= rs.getInt("train_id") %>">Delete</a></td>
        </tr>
<%      }
        rs.close(); %>
    </table>

    <!-- ================= Train Stops ================= -->
    <h3>Train Stops</h3>
    <form method="post" action="adminmanage.jsp">
        Line:
        <select name="line_id">
<%
        rs = st.executeQuery("SELECT line_id, name FROM TransitLine ORDER BY name");
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("line_id") %>"><%= rs.getString("name") %></option>
<%      }
        rs.close(); %>
        </select>
        Station:
        <select name="station_id">
<%
        rs = st.executeQuery("SELECT station_id, station_name FROM Station ORDER BY station_name");
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("station_id") %>"><%= rs.getString("station_name") %></option>
<%      }
        rs.close(); %>
        </select><br>
        Arrival: <input type="datetime-local" name="arrival">
        Departure: <input type="datetime-local" name="departure">
        <input type="submit" name="add_stop" value="Add Stop">
    </form>
    <table border="1" cellpadding="5">
        <tr><th>ID</th><th>Line</th><th>Station</th><th>Arrival</th><th>Departure</th><th></th></tr>
<%
        rs = st.executeQuery(
            "SELECT ts.stop_id, tl.name AS line_name, s.station_name, " +
            "       ts.arrival_datetime, ts.departure_datetime " +
            "FROM TrainStop ts " +
            "JOIN TransitLine tl ON ts.line_id = tl.line_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "ORDER BY ts.stop_id");
        while (rs.next()) {
%>
        <tr>
            <td><%= rs.getInt("stop_id") %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getString("station_name") %></td>
            <td><%= rs.getTimestamp("arrival_datetime") %></td>
            <td><%= rs.getTimestamp("departure_datetime") %></td>
            <td><a href="adminmanage.jsp?delete_stop=<%= rs.getInt("stop_id") %>">Delete</a></td>
        </tr>
<%      }
        rs.close(); %>
    </table>

    <!-- ================= Schedules ================= -->
    <h3>Schedules</h3>
    <form method="post" action="adminmanage.jsp">
        Line:
        <select name="line_id">
<%
        rs = st.executeQuery("SELECT line_id, name FROM TransitLine ORDER BY name");
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("line_id") %>"><%= rs.getString("name") %></option>
<%      }
        rs.close(); %>
        </select>
        Train:
        <select name="train_id">
<%
        rs = st.executeQuery("SELECT train_id FROM Train ORDER BY train_id");
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("train_id") %>"><%= rs.getInt("train_id") %></option>
<%      }
        rs.close(); %>
        </select>
        Stop:
        <select name="stop_id">
<%
        rs = st.executeQuery(
            "SELECT ts.stop_id, s.station_name, ts.departure_datetime " +
            "FROM TrainStop ts JOIN Station s ON ts.station_id = s.station_id " +
            "ORDER BY ts.stop_id");
        while (rs.next()) {
%>
            <option value="<%= rs.getInt("stop_id") %>">
                #<%= rs.getInt("stop_id") %> - <%= rs.getString("station_name") %>
                (<%= rs.getTimestamp("departure_datetime") %>)
            </option>
<%      }
        rs.close(); %>
        </select><br>
        Stops (description): <input type="text" name="stops" size="40" maxlength="100"><br>
        Arrival: <input type="datetime-local" name="arrival">
        Departure: <input type="datetime-local" name="departure">
        <input type="submit" name="add_schedule" value="Add Schedule">
    </form>
    <table border="1" cellpadding="5">
        <tr><th>ID</th><th>Line</th><th>Train</th><th>Stop Station</th>
            <th>Stops</th><th>Arrival</th><th>Departure</th><th></th></tr>
<%
        rs = st.executeQuery(
            "SELECT sc.schedule_id, tl.name AS line_name, sc.train_id, " +
            "       s.station_name, sc.stops, sc.arrival_time, sc.departure_time " +
            "FROM Schedule sc " +
            "JOIN TransitLine tl ON sc.line_id = tl.line_id " +
            "JOIN TrainStop ts ON sc.stop_id = ts.stop_id " +
            "JOIN Station s ON ts.station_id = s.station_id " +
            "ORDER BY sc.schedule_id");
        while (rs.next()) {
%>
        <tr>
            <td><%= rs.getInt("schedule_id") %></td>
            <td><%= rs.getString("line_name") %></td>
            <td><%= rs.getInt("train_id") %></td>
            <td><%= rs.getString("station_name") %></td>
            <td><%= rs.getString("stops") != null ? rs.getString("stops") : "-" %></td>
            <td><%= rs.getTimestamp("arrival_time") %></td>
            <td><%= rs.getTimestamp("departure_time") %></td>
            <td><a href="adminmanage.jsp?delete_schedule=<%= rs.getInt("schedule_id") %>">Delete</a></td>
        </tr>
<%      }
        rs.close();
        st.close(); %>
    </table>
<%
    } catch (Exception e) {
%>
    <p>Error: <%= e.getMessage() %></p>
<%
    } finally {
        if (conn != null) conn.close();
    }
%>
</body>
</html>
