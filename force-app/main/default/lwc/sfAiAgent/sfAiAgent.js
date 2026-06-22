import { LightningElement, track } from 'lwc';
import askAgent from '@salesforce/apex/SfAiAgentController.askAgent';

export default class SfAiAgent extends LightningElement {

    @track messages = [];
    @track isThinking = false;
    @track inputText = '';
    msgIdCounter = 0;

    // SVG path data for each icon (Material / custom paths)
    quickActions = [
        { id: 'q1', label: 'Fetch records',
        svg: 'M3 3h18v4H3zm0 6h18v2H3zm0 5h18v2H3zm0 5h18v2H3z',
        prompt: 'Show me all Account records with Name, Industry and AnnualRevenue, limit 10' },

        // ✅ Full describe — explicitly says "describe"
        { id: 'q2', label: 'Object metadata',
        svg: 'M12 2a10 10 0 1 0 0 20A10 10 0 0 0 12 2zm1 15h-2v-6h2zm0-8h-2V7h2z',
        prompt: 'Describe the Account object — full schema with all fields and child relationships' },

        // ✅ Child only
        { id: 'q3', label: 'Child records',
        svg: 'M17 12h-5v5h5v-5zM16 1v2H8V1H6v2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2h-1V1h-2zm3 18H5V8h14v11z',
        prompt: 'Show all child objects and relationships of the Account object' },

        { id: 'q4', label: 'Apex trigger',
        svg: 'M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z',
        prompt: 'Write an Apex trigger on Opportunity that fires on insert and update, fully bulkified' },

        { id: 'q5', label: 'LWC component',
        svg: 'M4 6h16v2H4zm0 5h16v2H4zm0 5h16v2H4z',
        prompt: 'Create an LWC that shows a list of Accounts using @wire with toast notification' },

        { id: 'q6', label: 'SOQL query',
        svg: 'M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
        prompt: 'Write SOQL to get all Contacts in the Technology industry with more than 500 employees' },
    ];

    orgActions = [
        {
            id: 'o1', label: 'OWD Settings',
            svg: 'M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 4l5 2.18V11c0 3.5-2.33 6.79-5 7.93-2.67-1.14-5-4.43-5-7.93V7.18L12 5z',
            prompt: 'Show me the OWD settings for this org'
        },
        {
            id: 'o2', label: 'Permission Sets',
            svg: 'M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z',
            prompt: 'List all permission sets in this org'
        },
        {
            id: 'o3', label: 'PS Groups',
            svg: 'M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z',
            prompt: 'List all permission set groups in this org'
        },
        {
            id: 'o4', label: 'Profiles',
            svg: 'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
            prompt: 'Show all profiles in this org'
        },
        {
            id: 'o5', label: 'Custom Objects',
            svg: 'M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 3c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm7 13H5v-.23c0-.62.28-1.2.76-1.58C7.47 15.82 9.64 15 12 15s4.53.82 6.24 2.19c.48.38.76.97.76 1.58V19z',
            prompt: 'List all custom objects in this org'
        },
        {
            id: 'o6', label: 'Active Flows',
            svg: 'M10.09 15.59L11.5 17l5-5-5-5-1.41 1.41L12.67 11H3v2h9.67l-2.58 2.59zM19 3H5a2 2 0 0 0-2 2v4h2V5h14v14H5v-4H3v4a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z',
            prompt: 'List all active flows in this org'
        }
    ];

    chips = [ // ✅ Changed — now asks for fields only, not full describe
        { id: 'c1', label: '👤 My User Info',      prompt: 'Who am I? Show my user info' },
        { id: 'c2', label: '📋 Account fields',    prompt: 'Show all fields on the Account object with their data types' },
        { id: 'c3', label: '🎨 Picklist fields',   prompt: 'Show all picklist fields on Account object' },
        { id: 'c4', label: '🏢 User roles',        prompt: 'Show all user roles in this org' },
        { id: 'c5', label: '✅ Validation rules',  prompt: 'Show validation rules for Account' },
        { id: 'c6', label: '📦 Apex classes',      prompt: 'List all Apex classes in this org' },
    ];

    get isSendDisabled() { return this.isThinking || !this.inputText.trim(); }

    connectedCallback() {
        this.addMessage('ai',
            '## 👋 Welcome to Salesforce AI Agent\n\n' +
            'I have **live access to your org** and I understand your intent — ask me to:\n\n' +
            '- **Show/List data** → I query your org directly\n' +
            '- **Write SOQL / Apex / LWC** → I generate code via GPT-4\n' +
            '- **Explain concepts** → I answer with best practices\n\n' +
            'Use the sidebar actions or chips below to get started!'
        );
    }

    addMessage(role, content) {
        const id = 'msg_' + (++this.msgIdCounter);
        const now  = new Date();
        const time = now.getHours().toString().padStart(2,'0') + ':' + now.getMinutes().toString().padStart(2,'0');
        const parsed = this.parseMessageContent(role, content);

        this.messages = [...this.messages, {
            id, role, content, time,
            html:    parsed.html,
            isHtml:  parsed.isHtml,
            isAi:    role === 'ai',
            wrapperClass: 'msg ' + role,
            avatarClass:  'msg-avatar ' + role,
            bubbleClass:  'bubble ' + role,
        }];
        this.scrollToBottom();
    }

    clearChat() {
        this.messages = [];
        this.addMessage('ai', '🔄 Conversation cleared. How can I help you?');
    }

    handleInput(event) {
        this.inputText = event.target.value;
        const ta = event.target;
        ta.style.height = 'auto';
        ta.style.height = Math.min(ta.scrollHeight, 120) + 'px';
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); this.sendMessage(); }
    }

    handleQuickAction(event) { this.inputText = event.currentTarget.dataset.prompt; this.sendMessage(); }
    handleChip(event)        { this.inputText = event.currentTarget.dataset.prompt; this.sendMessage(); }

    async sendMessage() {
        const text = this.inputText.trim();
        if (!text || this.isThinking) return;

        this.addMessage('user', text);
        this.inputText = '';
        const ta = this.template.querySelector('textarea[data-id="chatInput"]');
        if (ta) { ta.value = ''; ta.style.height = 'auto'; }
        this.isThinking = true;

        try {
            const reply = await askAgent({ prompt: text });
            this.addMessage('ai', reply);
        } catch (error) {
            this.addMessage('ai', '❌ **Error:** ' + (error.body?.message || error.message || 'Unknown error.'));
        } finally {
            this.isThinking = false;
        }
    }

    scrollToBottom() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const c = this.template.querySelector('.messages');
            if (c) c.scrollTop = c.scrollHeight;
        }, 60);
    }

    renderedCallback() {
        this.template.querySelectorAll('.msg-content').forEach(el => {
            const msg = this.messages.find(m => m.id === el.dataset.id);
            if (msg && msg.isHtml && el.innerHTML !== msg.html) {
                // eslint-disable-next-line @lwc/lwc/no-inner-html
                el.innerHTML = msg.html;
            }
        });
    }

    // ── Markdown parser (unchanged from previous version) ─────────────────────────
    parseMessageContent(role, content) {
        if (role !== 'ai' || !content) return { isHtml: false, html: '' };
        const hasCode  = /```/.test(content);
        const hasTable = this.containsPipeTable(content);
        const hasMd    = /\*\*|^#{1,3} |^[-*] /m.test(content);
        if (!hasCode && !hasTable && !hasMd) return { isHtml: false, html: '' };
        return { isHtml: true, html: this.mdToHtml(content) };
    }

    containsPipeTable(content) {
        const lines = content.split(/\r?\n/);
        let c = 0;
        for (const l of lines) { if (this.isPipeLine(l)) { c++; } else { if (c >= 2) return true; c = 0; } }
        return c >= 2;
    }

    isPipeLine(line) { return line.split('|').length >= 3; }

    mdToHtml(content) {
        const lines = content.split(/\r?\n/);
        const parts = []; let inCode = false; let codeLines = []; let inList = false;

        const flushCode = () => {
            if (!codeLines.length) return;
            parts.push('<div class="agent-code"><pre><code>' + this.esc(codeLines.join('\n')) + '</code></pre></div>');
            codeLines = [];
        };
        const flushList = () => { if (inList) { parts.push('</ul>'); inList = false; } };
        const fmt = t => t.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/`([^`]+)`/g,'<code class="inline-code">$1</code>');

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.trim().startsWith('```')) { if (inCode) { flushCode(); inCode=false; } else { flushList(); inCode=true; } continue; }
            if (inCode) { codeLines.push(line); continue; }
            if (this.isPipeLine(line)) {
                flushList(); flushCode();
                const tbl=[line]; let j=i+1;
                while (j<lines.length && this.isPipeLine(lines[j])) tbl.push(lines[j++]);
                if (tbl.length>=2) { parts.push(this.buildTable(tbl)); i=j-1; continue; }
            }
            const h1=line.match(/^# (.+)/); const h2=line.match(/^## (.+)/); const h3=line.match(/^### (.+)/);
            const li=line.match(/^[-*] (.+)/);
            if (h1) { flushList(); parts.push('<h3 class="md-h1">'+fmt(this.esc(h1[1]))+'</h3>'); continue; }
            if (h2) { flushList(); parts.push('<h4 class="md-h2">'+fmt(this.esc(h2[1]))+'</h4>'); continue; }
            if (h3) { flushList(); parts.push('<h5 class="md-h3">'+fmt(this.esc(h3[1]))+'</h5>'); continue; }
            if (li) { if (!inList) { parts.push('<ul class="md-list">'); inList=true; } parts.push('<li>'+fmt(this.esc(li[1]))+'</li>'); continue; }
            flushList();
            if (line.trim()==='') parts.push('<div class="md-spacer"></div>');
            else parts.push('<p class="md-p">'+fmt(this.esc(line))+'</p>');
        }
        flushCode(); flushList();
        return parts.join('');
    }

    buildTable(tableLines) {
        const clean = row => row.replace(/^\||\|$/g,'').split('|').map(c=>c.trim());
        const fmt = t => t.replace(/\*\*(.+?)\*\*/g,'<strong>$1</strong>').replace(/`([^`]+)`/g,'<code class="inline-code">$1</code>');
        const headers = clean(tableLines[0]);
        let start = (tableLines.length>1 && /^\|?\s*[-:]+[\s|:-]*$/.test(tableLines[1])) ? 2 : 1;
        let html = '<div class="agent-table-wrapper"><table class="agent-table"><thead><tr>';
        headers.forEach(h => { html += '<th>'+fmt(this.esc(h))+'</th>'; });
        html += '</tr></thead><tbody>';
        for (let i=start; i<tableLines.length; i++) {
            if (!tableLines[i].trim()) continue;
            html += '<tr>'; clean(tableLines[i]).forEach(c => { html += '<td>'+fmt(this.esc(c))+'</td>'; }); html += '</tr>';
        }
        html += '</tbody></table></div>';
        return html;
    }

    esc(v) { return String(v).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;'); }
}