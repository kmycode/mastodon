import { useCallback, useRef, useState } from 'react';

import { useIntl, defineMessages } from 'react-intl';

import classNames from 'classnames';

import { changeCircle } from '@/mastodon/actions/compose_typed';
import { Popover } from '@/mastodon/components/popover';
import type { Circle } from '@/mastodon/models/circle';
import { getOrderedCircles } from '@/mastodon/selectors/circles';
import CircleIcon from '@/material-icons/400-24px/account_circle.svg?react';
import { Icon } from 'mastodon/components/icon';
import { useAppSelector, useAppDispatch } from 'mastodon/store';

const messages = defineMessages({
  add_expiration: {
    id: 'status.expiration.add',
    defaultMessage: 'Set status expiration',
  },
});

const CircleDropdownMenu: React.FC<{
  items: Circle[];
  value: string;
  onClose: () => void;
  onChange: (arg0: string) => void;
}> = ({ items, value, onClose, onChange }) => {
  const circles = items;
  const nodeRef = useRef<HTMLDivElement>(null);
  const listNodeRef = useRef<HTMLDivElement>(null);

  const handleClick = useCallback(
    (e: React.MouseEvent | React.KeyboardEvent) => {
      const value = e.currentTarget.getAttribute('data-index');

      if (!value) {
        return;
      }

      e.preventDefault();

      onClose();
      onChange(value);
    },
    [onClose, onChange],
  );

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (!listNodeRef.current) {
        return;
      }

      const index = Array.from(listNodeRef.current.childNodes).findIndex(
        (node) => node === e.currentTarget,
      );

      let element = null;

      switch (e.key) {
        case 'Escape':
          onClose();
          break;
        case ' ':
        case 'Enter':
          handleClick(e);
          break;
        case 'ArrowDown':
          element =
            listNodeRef.current.childNodes[index + 1] ??
            listNodeRef.current.firstChild;
          break;
        case 'ArrowUp':
          element =
            listNodeRef.current.childNodes[index - 1] ??
            listNodeRef.current.lastChild;
          break;
        case 'Tab':
          if (e.shiftKey) {
            element =
              listNodeRef.current.childNodes[index - 1] ??
              listNodeRef.current.lastChild;
          } else {
            element =
              listNodeRef.current.childNodes[index + 1] ??
              listNodeRef.current.firstChild;
          }
          break;
        case 'Home':
          element = listNodeRef.current.firstChild;
          break;
        case 'End':
          element = listNodeRef.current.lastChild;
          break;
      }

      if (element && element instanceof HTMLElement) {
        element.focus();
        e.preventDefault();
        e.stopPropagation();
      }
    },
    [onClose, handleClick],
  );

  return (
    <div ref={nodeRef}>
      <div
        className='language-dropdown__dropdown__results emoji-mart-scroll'
        role='listbox'
        ref={listNodeRef}
      >
        {circles.map((circle) => (
          <div
            key={circle.id}
            role='option'
            tabIndex={0}
            data-index={circle.id}
            className={classNames(
              'language-dropdown__dropdown__results__item',
              { active: circle.id === value },
            )}
            aria-selected={circle.id === value}
            onClick={handleClick}
            onKeyDown={handleKeyDown}
          >
            <span className='language-dropdown__dropdown__results__item__native-name'>
              {circle.title}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export const CircleDropdown: React.FC = () => {
  const [open, setOpen] = useState(false);
  const activeElementRef = useRef<HTMLElement | null>(null);
  const [targetElement, setTargetElement] = useState<HTMLElement | null>(null);

  const intl = useIntl();

  const dispatch = useAppDispatch();
  const circles = useAppSelector((state) => getOrderedCircles(state));
  const value = useAppSelector(
    (state) => state.compose.get('circle_id') as string,
  );
  const unavailable = useAppSelector(
    (state) =>
      state.compose.get('privacy') !== 'circle' || !!state.compose.get('id'),
  );

  const current = circles.find((circle) => circle.id === value);

  const handleMouseDown = useCallback(() => {
    if (!open && document.activeElement instanceof HTMLElement) {
      activeElementRef.current = document.activeElement;
    }
  }, [open]);

  const handleToggle = useCallback(() => {
    if (open && activeElementRef.current)
      activeElementRef.current.focus({ preventScroll: true });

    setOpen(!open);
  }, [open, setOpen]);

  const handleClose = useCallback(() => {
    if (open && activeElementRef.current)
      activeElementRef.current.focus({ preventScroll: true });

    setOpen(false);
  }, [open, setOpen]);

  const handleChange = useCallback(
    (value: string) => {
      dispatch(changeCircle(value));
    },
    [dispatch],
  );

  if (unavailable) return null;

  return (
    <>
      <button
        type='button'
        ref={setTargetElement}
        title={intl.formatMessage(messages.add_expiration)}
        aria-expanded={open}
        onClick={handleToggle}
        onMouseDown={handleMouseDown}
        className={classNames('dropdown-button', {
          active: open,
        })}
      >
        <Icon id='clock-o' icon={CircleIcon} />
        <span className='dropdown-button__label'>{current?.title}</span>
      </button>

      <Popover
        isOpen={open}
        onClose={handleClose}
        offset={5}
        reference={targetElement}
      >
        {({ props, placement }) => (
          <div {...props}>
            <div
              className={`dropdown-animation language-dropdown__dropdown ${placement}`}
            >
              <CircleDropdownMenu
                value={value}
                items={circles}
                onClose={handleClose}
                onChange={handleChange}
              />
            </div>
          </div>
        )}
      </Popover>
    </>
  );
};
