import React, { useEffect, useState } from 'react';

// The proxy routes /gql/endpoint → rawInstanceUrl (my.salesforce.com) with Bearer auth injected.
// This is the only proxy route that works for authenticated Salesforce API calls from a UI bundle.
const GQL_ENDPOINT = '/gql/endpoint';

const ACCOUNT_QUERY = `
query AccountQuery {
    uiapi {
        query {
            Account(first: 10) {
                edges {
                    node {
                        Id
                        Name { value }
                        Industry { value }
                        AnnualRevenue { value }
                        Type { value }
                    }
                }
            }
        }
    }
}
`;

export default function App() {
    const [accounts, setAccounts] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    useEffect(() => {
        fetch(GQL_ENDPOINT, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ query: ACCOUNT_QUERY })
        })
            .then((res) => {
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                return res.json();
            })
            .then((data) => {
                if (data.errors?.length) {
                    throw new Error(data.errors[0].message);
                }
                const edges = data?.data?.uiapi?.query?.Account?.edges ?? [];
                setAccounts(edges.map((e) => e.node));
            })
            .catch((err) => setError(err.message))
            .finally(() => setLoading(false));
    }, []);

    return (
        <div style={styles.container}>
            <h1 style={styles.heading}>Interview App — Salesforce UI Bundle</h1>
            <p style={styles.sub}>
                Multi-framework preview via <strong>sf ui-bundle dev</strong> proxy →{' '}
                <code>/gql/endpoint</code>
            </p>

            {loading && <p style={styles.loading}>Loading accounts from Salesforce...</p>}
            {error && <p style={styles.error}>Error: {error}</p>}

            {!loading && !error && (
                <table style={styles.table}>
                    <thead>
                        <tr style={styles.headerRow}>
                            <th style={styles.th}>Name</th>
                            <th style={styles.th}>Type</th>
                            <th style={styles.th}>Industry</th>
                            <th style={styles.th}>Annual Revenue</th>
                        </tr>
                    </thead>
                    <tbody>
                        {accounts.length === 0 ? (
                            <tr>
                                <td colSpan={4} style={{ ...styles.td, color: '#888' }}>
                                    No accounts found in org.
                                </td>
                            </tr>
                        ) : (
                            accounts.map((acc) => (
                                <tr key={acc.Id} style={styles.row}>
                                    <td style={styles.td}>{acc.Name?.value ?? '—'}</td>
                                    <td style={styles.td}>{acc.Type?.value ?? '—'}</td>
                                    <td style={styles.td}>{acc.Industry?.value ?? '—'}</td>
                                    <td style={styles.td}>
                                        {acc.AnnualRevenue?.value != null
                                            ? `$${Number(acc.AnnualRevenue.value).toLocaleString()}`
                                            : '—'}
                                    </td>
                                </tr>
                            ))
                        )}
                    </tbody>
                </table>
            )}
        </div>
    );
}

const styles = {
    container: {
        fontFamily: "'Salesforce Sans', Arial, sans-serif",
        padding: '2rem',
        maxWidth: '900px',
        margin: '0 auto',
        color: '#181818'
    },
    heading:   { fontSize: '1.5rem', fontWeight: '700', marginBottom: '0.25rem' },
    sub:       { color: '#666', marginBottom: '1.5rem', fontSize: '0.9rem' },
    loading:   { color: '#0176d3' },
    error:     { color: '#ba0517' },
    table:     { width: '100%', borderCollapse: 'collapse', fontSize: '0.9rem' },
    headerRow: { background: '#f3f3f3' },
    th:        { textAlign: 'left', borderBottom: '2px solid #dddbda', padding: '10px 8px', fontWeight: '700', color: '#3e3e3c' },
    td:        { borderBottom: '1px solid #dddbda', padding: '10px 8px', color: '#3e3e3c' },
    row:       {}
};
