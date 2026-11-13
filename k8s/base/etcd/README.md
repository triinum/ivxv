# `k8s/base/etcd/`

etcd kui `storage` backend (StatefulSet). Pordid **2379** (klient) / **2380** (peer).

`storage` teenus (:2379) räägib etcd-ga PutGetter abstraktsiooni kaudu.
AWS tootmises kaalu hallatud asendust (DynamoDB / Postgres), kui PutGetter
backend seda toetab — etcd ei pea jääma ainukeseks valikuks.
