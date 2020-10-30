FROM traefik:v2.2
COPY ./traefik /etc/traefik
# HEALTHCHECK --interval=60s --timeout=3s --start-period=10s CMD [ "traefik healthcheck --ping" ]

ENTRYPOINT ["/etc/traefik/secret-entrypoint.sh"]

CMD ["traefik"]
