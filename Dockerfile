FROM elixir:1.14.2

# Update registry and install tesseract and dependencies
RUN apt-get update -qq \
  && apt-get install -y \
  poppler-utils \
  libtesseract-dev \
  libleptonica-dev \
  tesseract-ocr-por

WORKDIR app

COPY . .

RUN mix local.hex --force; \
  mix local.rebar --force; \
  mix do deps.get, deps.compile

RUN chmod +x ./entrypoint.sh

CMD ./entrypoint.sh
