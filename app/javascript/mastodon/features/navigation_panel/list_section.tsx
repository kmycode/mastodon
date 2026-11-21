import { useCallback, useState } from 'react';
import type { ReactNode } from 'react';

import { FormattedMessage } from 'react-intl';

import { CaretDownIcon } from '@phosphor-icons/react';
import { CaretUpIcon } from '@phosphor-icons/react/dist/ssr';

import { useStorageState } from '@/mastodon/hooks/useStorage';
import { useIdentity } from '@/mastodon/identity_context';
import { hasReactChildren } from '@/mastodon/utils/has_react_children';

import classes from './list_section.module.scss';

export const ListSection: React.FC<{
  title: ReactNode;
  /**
   * Unique identifier of this section, used for storing the
   * open/close state of the section in localStorage
   */
  id: string;
  children: ReactNode;
  emptyMessage?: ReactNode;
  hiddenChildren?: ReactNode;
  hiddenContentToggle?: ReactNode;
}> = ({
  title,
  id,
  children,
  emptyMessage,
  hiddenChildren,
  hiddenContentToggle,
}) => {
  const hasContent = hasReactChildren(children);
  const hasHiddenContent = hasReactChildren(hiddenChildren);

  const { accountId } = useIdentity();
  const storageKey = `ListSection-${id}-toggle-state-${accountId}`;
  const [isOpen, setIsOpen] = useStorageState<boolean>(storageKey, true);
  const [isOpenHiddenContent, setIsOpenHiddenContent] =
    useState<boolean>(false);
  const toggleIsOpen = useCallback(() => {
    setIsOpen(!isOpen);
  }, [isOpen, setIsOpen]);
  const toggleHiddenContent = useCallback(() => {
    setIsOpenHiddenContent(!isOpenHiddenContent);
  }, [isOpenHiddenContent, setIsOpenHiddenContent]);

  const hiddenContentToggleView = hasReactChildren(hiddenContentToggle) ? (
    hiddenContentToggle
  ) : (
    <div className={classes.hiddenContentToggle}>
      <button type='button' onClick={toggleHiddenContent}>
        <FormattedMessage
          id='tabs_bar.toggle_hidden'
          defaultMessage='Toggle hidden contents'
        />
        {isOpenHiddenContent ? <CaretUpIcon /> : <CaretDownIcon />}
      </button>
    </div>
  );

  return (
    <li className={classes.root}>
      <div className={classes.titleWrapper}>
        {hasContent ? (
          <button
            type='button'
            aria-expanded={isOpen}
            className={classes.title}
            onClick={toggleIsOpen}
          >
            {title}
            <CaretDownIcon className={classes.toggleIcon} />
          </button>
        ) : (
          <span className={classes.title}>{title}</span>
        )}
      </div>
      {hasContent
        ? isOpen && (
            <>
              <ul>{children}</ul>
              {hasHiddenContent && (
                <>
                  {isOpenHiddenContent && <ul>{hiddenChildren}</ul>}
                  {hiddenContentToggleView}
                </>
              )}
            </>
          )
        : emptyMessage && (
            <div className={classes.emptyState}>{emptyMessage}</div>
          )}
    </li>
  );
};
