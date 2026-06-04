FROM mambaorg/micromamba:2.0.5

WORKDIR /app

COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/environment.yml

RUN micromamba create -y -f /tmp/environment.yml \
    && micromamba run -n gen2kgbot python -m pip install "fastapi>=0.115,<1" "uvicorn[standard]>=0.30,<1" \
    && micromamba clean --all --yes

RUN micromamba run -n gen2kgbot python -m pip install "bcrypt<5"

ENV PATH=/opt/conda/envs/gen2kgbot/bin:$PATH
ENV PYTHONUNBUFFERED=1

COPY --chown=$MAMBA_USER:$MAMBA_USER . .

EXPOSE 8000

CMD ["python", "-m", "uvicorn", "app.api.q2forge_api:app", "--host", "0.0.0.0", "--port", "8000"]
