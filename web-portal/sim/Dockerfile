# Net-Desktop (Simulation) built straight from its own repository.
# Update to the latest commit with:  docker compose build --no-cache sim
FROM node:24-alpine
RUN apk add --no-cache git
ARG SIM_REPO=https://github.com/Mxles-Arm/Net-Desktop.git
ARG SIM_REF=main
WORKDIR /app
RUN git init -q && git remote add origin "$SIM_REPO" \
 && git fetch -q --depth 1 origin "$SIM_REF" && git checkout -q FETCH_HEAD \
 && rm -rf .git
# Temporary: make the frontend's /api/ calls relative so it works under /sim/.
COPY patch-paths.sh /tmp/patch-paths.sh
RUN sh /tmp/patch-paths.sh /app/frontend
RUN cd backend && npm ci --omit=dev
ENV NODE_ENV=production PORT=3000
EXPOSE 3000
CMD ["node", "backend/src/server.js"]
