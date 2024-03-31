# tf-stateful-managed

Using terraform, this repository creates a passtrough network ILB that serves port 800 IP.

The backend for the ILB is a backend with a stateful managed instance group. There are 2 VMs in the group, each one has a static external IP attached to it. This was done for demo purposes only.