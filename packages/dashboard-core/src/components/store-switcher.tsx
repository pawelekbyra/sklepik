import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  SidebarMenu,
  SidebarMenuItem,
  Skeleton,
  useSidebar,
} from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { ChevronsUpDownIcon, ExternalLinkIcon, PlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useStores } from '../hooks/use-stores'
import { getInitials } from '../lib/formatters'
import { useStore } from '../providers/store-provider'

// Plain `string` (not a template-literal type) so `Link`'s typed `to` prop
// accepts it the same way it accepts `NavItem.url` elsewhere in this
// package — dashboard-core has no route tree of its own to validate against.
function storeHref(storeId: string): string {
  return `/${storeId}`
}

function newStoreHref(storeId: string): string {
  return `/${storeId}/new-store`
}

export function StoreSwitcher() {
  const { t } = useTranslation()
  const { isMobile, state } = useSidebar()
  const isCollapsed = state === 'collapsed'

  const { store, storeId, isLoading } = useStore()
  const { data: stores } = useStores()

  if (isLoading) return <Skeleton className="h-header-height w-full rounded-xl" />

  const storeInitials = getInitials(store?.name, storeId)

  return (
    <SidebarMenu>
      <SidebarMenuItem className="h-header-height flex items-center">
        <DropdownMenu>
          <DropdownMenuTrigger asChild className="flex w-full items-center">
            <button
              type="button"
              className="rounded-xl outline-hidden transition-colors duration-100 hover:bg-sidebar-accent data-[state=open]:bg-sidebar-accent gap-2 p-1.5"
            >
              <Avatar>
                {store?.logo_url && <AvatarImage src={store.logo_url} />}
                <AvatarFallback>{storeInitials}</AvatarFallback>
              </Avatar>
              {!isCollapsed && (
                <>
                  <div className="grid flex-1 text-left text-sm leading-tight">
                    <span className="truncate font-medium text-foreground">{store?.name}</span>
                  </div>
                  <ChevronsUpDownIcon className="ml-auto size-4 text-muted-foreground" />
                </>
              )}
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            className="min-w-48"
            side={isMobile ? 'bottom' : 'right'}
            align="start"
            sideOffset={8}
          >
            {stores && stores.length > 1 && (
              <>
                <DropdownMenuLabel>{t('admin.account.your_stores')}</DropdownMenuLabel>
                {stores.map((s) => (
                  <DropdownMenuItem key={s.id} asChild>
                    <Link
                      to={storeHref(s.id)}
                      className="no-underline"
                      aria-current={s.id === storeId}
                    >
                      <Avatar className="size-5">
                        {s.logo_url && <AvatarImage src={s.logo_url} />}
                        <AvatarFallback className="text-[10px]">
                          {getInitials(s.name, s.id)}
                        </AvatarFallback>
                      </Avatar>
                      <span className="truncate">{s.name}</span>
                    </Link>
                  </DropdownMenuItem>
                ))}
                <DropdownMenuSeparator />
              </>
            )}
            <DropdownMenuItem>
              <ExternalLinkIcon className="size-4" />
              {t('admin.account.view_store')}
            </DropdownMenuItem>
            <DropdownMenuItem asChild>
              <Link to={newStoreHref(storeId)} className="no-underline">
                <PlusIcon className="size-4" />
                {t('admin.account.new_store')}
              </Link>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </SidebarMenuItem>
    </SidebarMenu>
  )
}
