FROM node:current-buster as build-deps
WORKDIR /app
COPY package.json yarn.lock ./
RUN yarn
COPY . ./
ARG NODE_GRAPHQL_ENDPOINT
ARG NODE_MAX_LOGS
ARG NODE_MAX_SWEEPS
RUN NODE_GRAPHQL_ENDPOINT=${NODE_GRAPHQL_ENDPOINT} NODE_MAX_LOGS=${NODE_MAX_LOGS} NODE_MAX_SWEEPS=${NODE_MAX_SWEEPS} yarn prod:build && mv ./static/* dist/

FROM nginx:alpine
COPY --from=build-deps /app/dist /usr/share/nginx/html
CMD ["nginx", "-g", "daemon off;"]
