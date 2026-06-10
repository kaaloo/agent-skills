# Translating Stitch concepts to react-dsfr

Use Stitch artifacts as visual references. Rebuild with project components.

## Component mapping

| Stitch or generic pattern | Production DSFR target |
| --- | --- |
| Page shell with logo and nav | `Header` and `Footer` from `@codegouvfr/react-dsfr` |
| Breadcrumb text row | `Breadcrumb` |
| Primary CTA | `Button` or `ButtonsGroup` |
| Information/error banner | `Alert` or `Notice` |
| Feature/result card | `Card` or `Tile` |
| Side navigation | `SideMenu` |
| Form input | `Input`, `Select`, `Checkbox`, `RadioButtons`, `ToggleSwitch`, `Upload` |
| Data table | `Table` with caption and accessible headers |
| Tabs/accordion | `Tabs`, `Accordion` |
| Dialog | `Modal` |
| Pagination controls | `Pagination` |
| Layout grid | `fr.cx("fr-container", "fr-grid-row", "fr-col-*")` utilities |

## Implementation rules

- Register the framework `Link` once according to the existing project setup.
- Use component-specific imports such as `@codegouvfr/react-dsfr/Button`.
- Use `fr.cx()` for DSFR utility classes.
- Keep the République Française brand block and service title consistent with project conventions.
- Use DSFR theme tokens or `useColors()` for custom styling. Do not copy Stitch hex values directly unless they are verified DSFR tokens.
- Replace generated placeholder imagery and copy with real service content.
- Preserve semantic heading order; do not copy visual heading sizes blindly.

## LaSuite variant

For LaSuite products, map app shell and collaborative UI patterns to `@gouvfr-lasuite/ui-kit` first:

- `MainLayout` for application frame.
- `QuickSearch` and `QuickSearchGroup` for global/entity search.
- `UserRow`, `Badge`, `DropdownMenu`, `ContextMenu`, and `Icon` for shared app patterns.
- `@gouvfr-lasuite/cunningham-react` for base form and modal components.
- Wrap with `CunninghamProvider` from `@gouvfr-lasuite/ui-kit`.

Do not mix DSFR page-shell assumptions into LaSuite application surfaces unless the project already does.
