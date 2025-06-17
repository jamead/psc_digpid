import matplotlib.pyplot as plt
import numpy as np

class PIDController:
    def __init__(self, kp, ki, kd, dt, output_limits=(-np.inf, np.inf)):
        self.kp = kp
        self.ki = ki
        self.kd = kd
        self.dt = dt

        self.integral = 0.0
        self.prev_error = 0.0

        self.min_out, self.max_out = output_limits

    def reset(self):
        self.integral = 0.0
        self.prev_error = 0.0

    def update(self, setpoint, measurement):
        error = setpoint - measurement
        self.integral += error * self.dt
        derivative = (error - self.prev_error) / self.dt

        output = (self.kp * error +
                  self.ki * self.integral +
                  self.kd * derivative)

        # Clamp output
        output = max(self.min_out, min(self.max_out, output))
        self.prev_error = error

        return output

# Simple plant model: first-order lag system
class Plant:
    def __init__(self, gain=1.0, tau=1.0, dt=0.01):
        self.gain = gain
        self.tau = tau
        self.dt = dt
        self.y = 0.0

    def update(self, u):
        # y[n+1] = y[n] + dt * (-y[n]/tau + gain*u/tau)
        dy = (-self.y + self.gain * u) / self.tau
        self.y += dy * self.dt
        return self.y

# Simulation parameters
dt = 0.01        # 10 ms sample time
T = 5.0          # total simulation time
N = int(T / dt)  # number of steps

# PID gains
kp = 10.0
ki = 2.0
kd = 0.01

# Setup
pid = PIDController(kp, ki, kd, dt, output_limits=(-10, 10))
plant = Plant(gain=1.0, tau=0.5, dt=dt)

# Setpoint and logs
setpoint = np.ones(N) * 1.0  # step input
y_vals = []
u_vals = []
t_vals = []

# Run simulation
for i in range(N):
    t = i * dt
    y = plant.y
    u = pid.update(setpoint[i], y)
    plant.update(u)

    y_vals.append(y)
    u_vals.append(u)
    t_vals.append(t)

# Plot results
plt.figure(figsize=(10, 5))
plt.subplot(2, 1, 1)
plt.plot(t_vals, setpoint, 'k--', label='Setpoint')
plt.plot(t_vals, y_vals, label='Output')
plt.ylabel('Output')
plt.legend()
plt.grid(True)

plt.subplot(2, 1, 2)
plt.plot(t_vals, u_vals, label='Control effort (u)')
plt.xlabel('Time (s)')
plt.ylabel('Control')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.show()

