FROM ghcr.io/xyzensun/codespace-java-go-ts-py:cnb@sha256:361cc7e13a893a7471b1c66f33bb63779087ceab7024ba0415e82af8cf27c3c6
RUN git config --system tag.gpgSign false && git config --system commit.gpgsign false
RUN npm install -g @mindfoldhq/trellis && npm install -g @anthropic-ai/claude-code