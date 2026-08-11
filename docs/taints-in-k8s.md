
## Taints 
In Kubernetes, a taint is a property you apply to a node that prevents pods from being scheduled onto a node. unless those pods explicitly tolerate the taint.

Think of it like this:
Node selector = "Put this pod on these nodes."
Taint (on Node) → "Keep pods away from me."
Toleration (on Pod) → "I'm allowed to run on that tainted node."

Taint the node 
```
kubectl taint nodes node1 dedicated=database:NoSchedule
```

Pod with toleration

```
apiVersion: v1
kind: Pod
metadata:
  name: db-pod
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "database"
    effect: "NoSchedule"

  containers:
  - name: mysql
    image: mysql
```



### Node Selector 

Node selector = "Put this pod on these nodes."
Taint = "Keep these pods away from this node."

```
kubectl label node node-2 role=backend
kubectl label node node-3 role=gpu
```

pod yaml file 

```
spec:
  nodeSelector:
    role: backend

```