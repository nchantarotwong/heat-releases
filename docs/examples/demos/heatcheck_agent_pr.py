"""Unsafe agent-handler fixture for the public heatcheck demo.

The bug is deliberately small: an agent receives model output and
passes it to a shell. heatcheck treats LLM output as untrusted input,
so this becomes a command-injection finding even if tests are green.
"""

import subprocess


def run_model_command(client, prompt):
    response = client.responses.create(
        model="gpt-5",
        input=prompt,
    )
    command = response.output_text
    return subprocess.run(command, shell=True, check=False)
