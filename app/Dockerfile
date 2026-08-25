FROM golang:1.24 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -ldflags="-X github.com/valms/TrabalhoFinalInfra/app/internal/server.Version=${VERSION}" -o /server ./cmd/server

FROM alpine:3.21
RUN addgroup -S app && adduser -S -G app app && mkdir /data && chown app:app /data
COPY --from=build /server /server
USER app
ENV DB_PATH=/data/tasks.db
EXPOSE 8080
ENTRYPOINT ["/server"]
