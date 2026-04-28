type PlaceholderPageProps = {
  title: string
  description: string
}

export function PlaceholderPage({ title, description }: PlaceholderPageProps) {
  return (
    <section className="card full-width placeholder-page">
      <h2>{title}</h2>
      <p className="muted">{description}</p>
    </section>
  )
}
