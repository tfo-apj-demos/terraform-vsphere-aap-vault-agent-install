FROM srlynch1/terraform-ai-tools:latest

RUN npm install -g @anthropic-ai/claude-code ccstatusline && \
    npm cache clean --force

# Create Claude configuration directory and configure status line for node user
RUN mkdir -p /home/node/.claude && \
    chown -R node:node /home/node/.claude && \
    chmod 700 /home/node/.claude && \
    touch /home/node/.claude/.claude.json && \
    chown node:node /home/node/.claude/.claude.json && \
    chmod 600 /home/node/.claude/.claude.json


# Add clauded alias for claude -dangerously-skip-permissions
RUN echo 'alias clauded="claude --dangerously-skip-permissions"' >> /home/node/.zshrc && \
    chown node:node /home/node/.zshrc