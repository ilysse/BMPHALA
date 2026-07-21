<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>BMP SMS Gateway</title>
    <style>
        :root {
            color-scheme: light;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: #f3f4f6;
            color: #111827;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            padding: 18px;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        main {
            width: min(100%, 520px);
            background: white;
            border: 1px solid #e5e7eb;
            border-radius: 16px;
            padding: 20px;
            box-shadow: 0 18px 45px rgba(15, 23, 42, 0.08);
        }

        h1 {
            margin: 0 0 6px;
            font-size: 24px;
        }

        p {
            margin: 0 0 16px;
            color: #4b5563;
            line-height: 1.45;
        }

        label {
            display: block;
            margin: 14px 0 6px;
            font-weight: 700;
            font-size: 13px;
        }

        input,
        textarea {
            width: 100%;
            border: 1px solid #d1d5db;
            border-radius: 10px;
            padding: 12px;
            font: inherit;
        }

        textarea {
            min-height: 120px;
            resize: vertical;
        }

        .row {
            display: grid;
            gap: 10px;
            grid-template-columns: 1fr 1fr;
            margin-top: 14px;
        }

        button,
        a.button {
            width: 100%;
            border: 0;
            border-radius: 10px;
            padding: 12px 14px;
            font: inherit;
            font-weight: 800;
            text-align: center;
            text-decoration: none;
            cursor: pointer;
            background: #2563eb;
            color: white;
        }

        button.secondary {
            background: #4b5563;
        }

        button.success {
            background: #059669;
        }

        button.danger {
            background: #dc2626;
        }

        button:disabled,
        a.button.disabled {
            background: #9ca3af;
            cursor: not-allowed;
        }

        .status {
            margin-top: 14px;
            padding: 12px;
            border-radius: 10px;
            background: #eff6ff;
            color: #1e3a8a;
            font-weight: 700;
        }

        .message {
            display: none;
            margin-top: 18px;
            padding-top: 16px;
            border-top: 1px solid #e5e7eb;
        }
    </style>
</head>
<body>
<main>
    <h1>BMP SMS Gateway</h1>
    <p>Open this page on the old phone that has the SIM card. Keep it open while OTP SMS delivery is needed.</p>

    <label for="token">Gateway token</label>
    <input id="token" type="password" autocomplete="off" placeholder="X-Gateway-Token">

    <div class="row">
        <button id="saveToken" type="button">Save Token</button>
        <button id="pollNow" type="button" class="secondary">Poll Now</button>
    </div>

    <div id="status" class="status">Idle. Save token, then poll.</div>

    <section id="messagePanel" class="message">
        <label for="toPhone">To</label>
        <input id="toPhone" readonly>

        <label for="body">Message</label>
        <textarea id="body" readonly></textarea>

        <div class="row">
            <a id="openSms" class="button" href="#">Open SMS App</a>
            <button id="markSent" type="button" class="success">Mark Sent</button>
        </div>
        <div class="row">
            <button id="markDelivered" type="button" class="success">Mark Delivered</button>
            <button id="markFailed" type="button" class="danger">Mark Failed</button>
        </div>
    </section>
</main>

<script>
    const apiBase = `${window.location.origin}/api/v1`;
    const tokenInput = document.getElementById('token');
    const statusBox = document.getElementById('status');
    const messagePanel = document.getElementById('messagePanel');
    const toPhone = document.getElementById('toPhone');
    const body = document.getElementById('body');
    const openSms = document.getElementById('openSms');
    let currentMessage = null;
    let polling = null;

    tokenInput.value = localStorage.getItem('bmp_sms_gateway_token') || '';

    function setStatus(text) {
        statusBox.textContent = text;
    }

    function headers() {
        return {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Gateway-Token': tokenInput.value.trim(),
        };
    }

    async function pollNext() {
        if (!tokenInput.value.trim()) {
            setStatus('Gateway token is required.');
            return;
        }

        if (currentMessage) {
            return;
        }

        try {
            const response = await fetch(`${apiBase}/sms-gateway/messages/next`, {
                method: 'GET',
                headers: headers(),
            });
            const json = await response.json();
            if (!response.ok || json.success !== true) {
                throw new Error(json.message || 'Polling failed.');
            }

            if (!json.data) {
                messagePanel.style.display = 'none';
                setStatus(`No pending SMS. Last check: ${new Date().toLocaleTimeString()}`);
                return;
            }

            currentMessage = json.data;
            toPhone.value = currentMessage.to_phone;
            body.value = currentMessage.body;
            openSms.href = `sms:${encodeURIComponent(currentMessage.to_phone)}?body=${encodeURIComponent(currentMessage.body)}`;
            messagePanel.style.display = 'block';
            setStatus('Message claimed. Open the SMS app and send it.');
        } catch (error) {
            setStatus(error.message || 'Gateway error.');
        }
    }

    async function updateStatus(status) {
        if (!currentMessage) {
            setStatus('No active message.');
            return;
        }

        try {
            const response = await fetch(`${apiBase}/sms-gateway/messages/${currentMessage.id}/status`, {
                method: 'POST',
                headers: headers(),
                body: JSON.stringify({
                    status,
                    provider_reference: `phone-${Date.now()}`,
                    error: status === 'failed' ? 'Marked failed from phone gateway page.' : null,
                }),
            });
            const json = await response.json();
            if (!response.ok || json.success !== true) {
                throw new Error(json.message || 'Status update failed.');
            }

            currentMessage = null;
            toPhone.value = '';
            body.value = '';
            messagePanel.style.display = 'none';
            setStatus(`Message marked ${status}. Polling for the next SMS.`);
            pollNext();
        } catch (error) {
            setStatus(error.message || 'Status update failed.');
        }
    }

    document.getElementById('saveToken').addEventListener('click', () => {
        localStorage.setItem('bmp_sms_gateway_token', tokenInput.value.trim());
        setStatus('Token saved. Polling every 10 seconds.');
        clearInterval(polling);
        polling = setInterval(pollNext, 10000);
        pollNext();
    });

    document.getElementById('pollNow').addEventListener('click', pollNext);
    document.getElementById('markSent').addEventListener('click', () => updateStatus('sent'));
    document.getElementById('markDelivered').addEventListener('click', () => updateStatus('delivered'));
    document.getElementById('markFailed').addEventListener('click', () => updateStatus('failed'));

    if (tokenInput.value.trim()) {
        polling = setInterval(pollNext, 10000);
        pollNext();
    }
</script>
</body>
</html>
