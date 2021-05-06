#!/bin/bash
# post-hook see renewalparams in /etc/letsencrypt/renewal/$(hostname -f).conf

# replace mail certificate
cat /etc/letsencrypt/live/$(hostname -f)/fullchain.pem /etc/letsencrypt/live/$(hostname -f)/privkey.pem >/etc/pmg/pmg-tls.pem
chown root:root /etc/pmg/pmg-tls.pem
chmod 600 /etc/pmg/pmg-tls.pem

# replace http certificate
cat /etc/letsencrypt/live/$(hostname -f)/fullchain.pem /etc/letsencrypt/live/$(hostname -f)/privkey.pem >/etc/pmg/pmg-api.pem
chown root:www-data /etc/pmg/pmg-api.pem
chmod 640 /etc/pmg/pmg-api.pem

# get old HASH from the cluster config
OLDHASH="$(grep "name $(hostname)$" /etc/pmg/cluster.conf -B4 | grep fingerprint | awk '{print $2}')"
# get certificate hash from the new hash file
NEWHASH="$(openssl x509 -in /etc/pmg/pmg-api.pem -noout -fingerprint -sha256 | cut -d'=' -f2)"

# update cluster config only when hash is updated
if [ "$OLDHASH" != "$NEWHASH" ]
then
          echo -e "The hash: \n${OLDHASH}\nwill be replaced with\n${NEWHASH}\n"
            sed -i.bak -e "s/$OLDHASH/$NEWHASH/g" /etc/pmg/cluster.conf
    fi

    # get own IP adress
    OWNIP="$(hostname -i)"
    # get all IP addresses from cluster, and remove OWNIP
    OTHERS=$(grep $'\tip' /etc/pmg/cluster.conf | grep -v ${OWNIP} | awk '{print $2}')

    # loop through $OTHERS and copy cluster.conf file, and then restart pmg on that host if copy went OK
    for host in $OTHERS
    do
              echo "Copy updated cluster.conf to ${host}."
                if scp  /etc/pmg/cluster.conf user@${host}:/etc/pmg/cluster.conf 2>&1 >/dev/null
                          then
                                      echo "Restarting PMGproxy on ${host}"
                                          ssh user@${host} systemctl restart pmgproxy
                                            else
                                                        echo "Copy went wrong";
                                                          fi
                                                  done
                                                  systemctl restart pmgproxy
