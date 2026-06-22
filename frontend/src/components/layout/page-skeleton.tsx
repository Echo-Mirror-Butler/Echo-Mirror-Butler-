
export function PageSkeleton() {
  return (
    <>
      <style>{`
        @keyframes skeleton-pulse {
          0%, 100% { opacity: 0.6; }
          50% { opacity: 1; }
        }
        @keyframes skeleton-spin {
          to { transform: rotate(360deg); }
        }
        .sk-pulse {
          animation: skeleton-pulse 1.5s infinite ease-in-out;
        }
        .sk-spin {
          animation: skeleton-spin 1s infinite linear;
        }
      `}</style>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '1.5rem',
          padding: '2rem',
          width: '100%',
          maxWidth: '1200px',
          margin: '0 auto',
          boxSizing: 'border-box',
        }}
      >
        {/* Header skeleton */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div
            className="sk-pulse"
            style={{
              width: '200px',
              height: '2.5rem',
              background: 'var(--line, #e5e7eb)',
              borderRadius: '8px',
            }}
          />
          <div
            className="sk-pulse"
            style={{
              width: '120px',
              height: '2rem',
              background: 'var(--line, #e5e7eb)',
              borderRadius: '20px',
            }}
          />
        </div>

        {/* Main card skeleton */}
        <div
          className="sk-pulse"
          style={{
            width: '100%',
            height: '300px',
            background: 'var(--surface, #ffffff)',
            border: '1px solid var(--line, #e5e7eb)',
            borderRadius: '16px',
            padding: '2rem',
            boxSizing: 'border-box',
            display: 'flex',
            flexDirection: 'column',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <div
            className="sk-spin"
            style={{
              width: '50px',
              height: '50px',
              border: '3px solid var(--line, #e5e7eb)',
              borderTopColor: 'var(--brand, #1463ff)',
              borderRadius: '50%',
              marginBottom: '1rem',
            }}
          />
          <div
            style={{
              width: '150px',
              height: '1rem',
              background: 'var(--line, #e5e7eb)',
              borderRadius: '4px',
            }}
          />
        </div>

        {/* Grid skeletons */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
            gap: '1.5rem',
          }}
        >
          {[1, 2].map((i) => (
            <div
              key={i}
              className="sk-pulse"
              style={{
                height: '180px',
                background: 'var(--surface, #ffffff)',
                border: '1px solid var(--line, #e5e7eb)',
                borderRadius: '16px',
                padding: '1.5rem',
                boxSizing: 'border-box',
                display: 'flex',
                flexDirection: 'column',
                gap: '1rem',
                animationDelay: `${i * 0.2}s`,
              }}
            >
              <div
                style={{
                  width: '40%',
                  height: '1.25rem',
                  background: 'var(--line, #e5e7eb)',
                  borderRadius: '4px',
                }}
              />
              <div
                style={{
                  width: '100%',
                  height: '3.5rem',
                  background: 'var(--line, #e5e7eb)',
                  borderRadius: '4px',
                }}
              />
              <div
                style={{
                  width: '70%',
                  height: '1rem',
                  background: 'var(--line, #e5e7eb)',
                  borderRadius: '4px',
                }}
              />
            </div>
          ))}
        </div>
      </div>
    </>
  );
}
